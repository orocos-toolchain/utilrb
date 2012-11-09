require 'thread'

module Utilrb
    # ThreadPool implementation inspired by
    # https://github.com/meh/ruby-threadpool
    #
    # @example Using a thread pool of 10 threads
    #   pool = ThreadPool.new(10)
    #   0.upto(9) do 
    #      pool.process do 
    #        sleep 1
    #        puts "done"
    #      end
    #   end
    #   pool.shutdown
    #   pool.join
    class ThreadPool
        # A Task is executed by the thread pool as soon as
        # a free thread is available.
        class Task
            Timeout = Class.new(Exception)
            Asked = Class.new(Exception)

            # Thread pool the task belongs to
            #
            # @return [ThreadPool] the thread pool
            attr_reader :pool

            # State of the task
            # 
            # @return [:waiting,:running,:finished,:timeout,:terminated,:exception] the state
            attr_reader :state

            # The exception thrown by the custom code block
            #
            # @return [Exception] the exception
            attr_reader :exception

            # The thread the task was assigned to
            #
            # return [Thread] the thread
            attr_reader :thread

            # The time the task was started
            #
            # return [Time] the time
            attr_reader :started_at

            # The time the task was stopped or finished
            #
            # return [Time] the time
            attr_reader :stopped_at

            # Result of the code block call
            attr_reader :result

            # Custom description which can be used
            # to store a human readable object
            attr_accessor :description

            # Maximum number of seconds until
            # the execution will timeout
            attr_accessor :timeout

            # Checks if the task was started
            #
            # @return [Boolean]
            def started?; @state != :waiting; end

            # Checks if the task is running
            #
            # @return [Boolean]
            def running?; @state == :running; end

            # Checks if the task was stopped or finished.
            # This also includes timeouts and cases where
            # an exception was raised by the custom code block.
            #
            # @return [Boolean]
            def finished?; started? && !running?; end

            # Checks if the task was successfully finished.
            # This means no exceptions, termination or timed out occurred
            #
            # @return [Boolean]
            def successfull?; @state == :finished; end

            # Checks if a timeout occurred
            #
            # @return [Boolean]
            def timeout?; @state == :timeout; end

            # Checks if the task was terminated.
            #
            # @return [Boolean]
            def terminated?; @state == :terminated; end

            # Checks if an exception occurred.
            #
            # @return [Boolean]
            def exception?; @state == :exception; end

            # A new task which can be added to the work queue of a {ThreadPool}
            #
            # @param [Array] args The arguments for the code block 
            # @param [Proc] block The code block
            def initialize (*args, &block)
                unless block
                    raise ArgumentError, 'you must pass a work block to initialize a new Task.'
                end
                @arguments = args
                @block = block
                @state = :waiting
                @mutex = Mutex.new
                @pool = nil
                @callback = nil
                @error_handler = nil
            end

            # Resets the tasks.
            # This can be used to requeue a task that is already finished
            def reset
                if finished?
                    @state = :waiting
                    @exception = nil
                    @result = nil
                    @started_at = nil
                    @stopped_at = nil
                else
                    raise RuntimeError,"cannot reset a task which is not finished"
                end
            end
 
            # Executes the task.
            # Should be called from a worker thread
            def execute(pool=nil)
                @mutex.synchronize do 
                    return if @state != :waiting

                    #store current thread to be able to terminate
                    #the thread
                    @pool = pool
                    @thread = Thread.current
                    @started_at = Time.now
                    @state = :running
                end

                state = begin
                            @result = @block.call(*@arguments)
                            :finished
                        rescue Exception => e
                            @exception = e
                            if e.is_a? Timeout
                                :timeout
                            elsif e.is_a? Asked
                                :terminated
                            else
                                :exception
                            end
                        end
                @stopped_at = Time.now

                # state must be written at last to ensure
                # all post process variables are initialized
                @mutex.synchronize do
                    @thread = nil
                    @state = state
                    @pool = nil
                end
                if successfull?
                    @callback.call @result if @callback
                else
                    @error_handler.call @exception if @error_handler
                end
            end

            # Terminates the task if it is running
            def terminate!(exception = Asked)
                @mutex.synchronize do
                    return unless running?
                    @thread.raise exception
                end
            end

            # Called from the worker thread when the work is done 
            #
            # @yield [Object] The callback
            def callback(&block)
                @mutex.synchronize do
                    @callback = block
                end
            end

            # Called from the worker thread when an Error occurred
            #
            # @yield [Exception] The error handler
            def error_handler(&block)
                @mutex.synchronize do
                    @error_handler= block 
                end
            end

            # Raises an timout Exception on the assigned thread
            def timeout!
                terminate! Timeout
            end

            # Sets the timeout for the task. If the thread pool has a running
            # watchdog and the task was running for longer than the given time
            # period the task is timed out.
            #
            # @param[Float] timeout The timeout in seconds
            def timeout=(timeout)
                @timeout = timeout
                @mutex.synchronize do
                    @pool.wake_up_watchdog if @pool
                end
            end

            # Returns the number of seconds the task is or was running
            #
            # @result [Float]
            def time_elapsed
                #no need to synchronize here
                if running?
                    (Time.now-@started_at).to_f
                elsif finished?
                    (@stopped_at-@started_at).to_f
                else
                    0
                end
            end
        end

        # The minimum number of worker threads.
        #
        # @return [Fixnum]
        attr_reader :min

        # The maximum number of worker threads.
        #
        # @return [Fixnum]
        attr_reader :max

        # The real number of worker threads.
        #
        # @return [Fixnum]
        attr_reader :spawned

        # The number of worker threads waiting for work.
        #
        # @return [Fixnum]
        attr_reader :waiting

        # Auto trim automatically reduces the number of worker threads if there are too many
        # threads waiting for work.
        # @param [Boolean] 
        # @return [Boolean]
        attr_accessor :auto_trim

        # A ThreadPool
        #
        # @param [Fixnum] min the minimum number of threads
        # @param [Fixnum] max the maximum number of threads
        def initialize (min = 5, max = min)
            @min = min
            @max = max

            @cond = ConditionVariable.new
            @mutex = Mutex.new

            @tasks_waiting = []         # tasks waiting for execution
            @tasks_running = []         # tasks which are currently running

            @workers = []               # thread pool
            @spawned = 0
            @waiting = 0
            @shutdown = false
            @block_on_task_finished = nil
            @pipes = nil

            @trim_requests = 0
            @auto_trim = false

            @mutex.synchronize do
                min.times do
                    spawn_thread
                end
            end
        end

        # Checks if the thread pool is shutting down all threads.
        #
        # @result [boolean]
        def shutdown?; @shutdown; end

        # Changes the minimum and maximum number of threads
        #
        # @param [Fixnum] min the minimum number of threads
        # @param [Fixnum] max the maximum number of threads
        def resize (min, max = nil)
            @mutex.synchronize do
                @min = min
                @max = max || min
                count = [@tasks_waiting.size,@max].min
                0.upto(count) do 
                    spawn_thread
                end
            end
            trim true
        end

        # Number of tasks waiting for execution
        # 
        # @return [Fixnum] the number of tasks
        def backlog
           @mutex.synchronize do 
                @tasks_waiting.length
            end
        end

        # Returns an array of the current waiting and running tasks
        #
        # @return [Array<Task>] The tasks
        def tasks
            @mutex.synchronize do
                 @tasks_running.dup + @tasks_waiting.dup
            end
        end

        # Processes the given block as soon as the next thread is available.
        #
        # @param [Array] args the block arguments
        # @yield [*args] the block
        # @return [Task]
        def process (*args, &block)
            task = Task.new(*args, &block)
            self << task
        end

        # Processes the given {Task} as soon as the next thread is available
        # 
        # @param [Task] task The task.
        # @return [Task]
        def <<(task)
            task.reset if task.finished?
            @mutex.synchronize do
                if shutdown? 
                    warn "unable to add work while shutting down"
                    return task
                end
                @tasks_waiting << task
                if @waiting == 0 && @spawned < @max
                    spawn_thread
                end
                @cond.signal
            end
            task
        end

        # Trims the number of threads if threads are waiting for work and 
        # the number of spawned threads is higher than the minimum number.
        #
        # @param [boolean] force Trim even if no thread is waiting.
        def trim (force = false)
            @mutex.synchronize do
                if (force || @waiting > 0) && @spawned - @trim_requests > @min
                    @trim_requests += 1
                    @cond.signal
                end
            end
            self
        end

        # Shuts down all threads.
        #
        # @param [Float] maximal number of seconds shutdown is waiting for a running thread
        def shutdown(timeout = nil)
            tasks = nil
            @mutex.synchronize do
                @shutdown = true
                @cond.broadcast
                tasks = if timeout
                            @tasks_running.dup
                        else
                            []
                        end
            end
            tasks.each do |task|
                if !task.timeout || (task.timeout - task.time_elapsed).to_f > timeout
                    task.timeout = (task.time_elapsed + timeout).to_f
                end
            end
            watchdog if timeout
        end

        # Blocks until all threads were terminated.
        # This does not terminate any thread by itself and will block for ever
        # if shutdown was not called.
        def join
            @workers.first.join until @workers.empty?
            wake_up_watchdog
            @watchdog.join if @watchdog
            self
        end

        # Activates a watchdog checking all tasks timeouts.
        def watchdog
            @mutex.synchronize do
                if !@watchdog
                    spawn_watchdog
                else
                    wake_up_watchdog
                end
            end
        end

        # Given code block is called for every task which was
        # finished even it was terminated or timeout.
        #
        # This can be used to store the result for an event loop
        #
        # @yield [Task] the code block
        def on_task_finished (&block)
            @mutex.synchronize do
                @block_on_task_finished = block
            end
        end

        # Wakes up the watchdog if the watchdog is waiting for 
        # the next timeout
        def wake_up_watchdog
            if @pipes
                @pipes.last.write_nonblock 'x' rescue nil
            end
        end

        private
        # spawns a worker thread
        # must be called from a synchronized block
        def spawn_thread
            thread = Thread.new do
                while !shutdown? do
                    task = @mutex.synchronize do
                        while @tasks_waiting.empty? && !shutdown? do 
                            if @trim_requests > 0
                                @trim_requests -= 1
                                break
                            end
                            @waiting += 1
                            @cond.wait @mutex
                            @waiting -= 1
                        end
                        if !shutdown?
                            @tasks_running << @tasks_waiting.shift
                            @tasks_running.last
                        end
                    end or break
                    wake_up_watchdog
                    task.execute(self)
                    @mutex.synchronize do
                        @tasks_running.delete task
                        @block_on_task_finished.call(task) if @block_on_task_finished
                    end
                    trim if auto_trim
                end

                # we do not have to lock here
                # because spawn_thread must be called from
                # a synchronized block
                @spawned -= 1
                @workers.delete thread
            end
            @spawned += 1
            @workers << thread
        end

        # Spawns a watchdog thread checking the timeouts for each task running
        # must be called from a synchronized block
        def spawn_watchdog
            return if @watchdog
            @pipes = IO.pipe
            @watchdog = Thread.new do
                while !shutdown? || @spawned > 0 do
                    #sleep until the next timeout will occur
                    now = Time.now
                    timeout = @mutex.synchronize do 
                        if !@tasks_running.empty?
                            @tasks_running.map do |task|
                                next unless task.started_at
                                now - task.started_at + task.timeout
                            end.compact.min
                        end
                    end
                    readable, = IO.select([@pipes.first], nil, nil, timeout)
                    if readable && !readable.empty?
                        readable.first.read_nonblock 1024
                    end

                    #check all tasks if they timed out
                    now = Time.now
                    @mutex.synchronize do 
                        @tasks_running.each do  |task|
                            if now >= task.started_at + task.timeout
                                task.timeout!
                            end
                        end
                    end
                end
            end
        end
    end
end
