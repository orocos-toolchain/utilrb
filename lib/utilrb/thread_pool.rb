require 'thread'
require 'set'
require 'utilrb/kernel/options'
require 'timeout'

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
    #
    # @author Alexander Duda <Alexander.Duda@dfki.de>
    class ThreadPool
        # A Task is executed by the thread pool as soon as
        # a free thread is available.
        #
        # @author Alexander Duda <Alexander.Duda@dfki.de>
        class Task
            Asked = Class.new(Exception)

            # The sync key is used to speifiy that a given task must not run in
            # paralles with another task having the same sync key. If no key is
            # set there are no such constrains for the taks.
            #
            # @return  the sync key
            attr_reader :sync_key

            # Thread pool the task belongs to
            #
            # @return [ThreadPool] the thread pool
            attr_reader :pool

            # State of the task
            # 
            # @return [:waiting,:running,:stopping,:finished,:terminated,:exception] the state
            attr_reader :state

            # The exception thrown by the custom code block
            #
            # @return [Exception] the exception
            attr_reader :exception

            # The thread the task was assigned to
            #
            # return [Thread] the thread
            attr_reader :thread

            # The time the task was queued 
            #
            # return [Time] the time
            attr_accessor :queued_at

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

            # Checks if the task was started
            #
            # @return [Boolean]
            def started?; @state != :waiting; end

            # Checks if the task is running
            #
            # @return [Boolean]
            def running?; @state == :running; end

            # Checks if the task is going to be stopped
            #
            # @return [Boolean]
            def stopping?; @state == :stopping; end

            # Checks if the task was stopped or finished.
            # This also includes cases where
            # an exception was raised by the custom code block.
            #
            # @return [Boolean]
            def finished?; started? && !running? && !stopping?; end

            # Checks if the task was successfully finished.
            # This means no exceptions, termination or timed out occurred
            #
            # @return [Boolean]
            def successfull?; @state == :finished; end

            # Checks if the task was terminated.
            #
            # @return [Boolean]
            def terminated?; @state == :terminated; end

            # Checks if an exception occurred.
            #
            # @return [Boolean]
            def exception?; @state == :exception; end

            # A new task which can be added to the work queue of a {ThreadPool}.
            # If a sync key is given no task having the same key will be 
            # executed in parallel which is useful for instance member calls
            # which are not thread safe.
            #
            # @param [Hash] options The options of the task.
            # @option options [Object] :sync_key The sync key
            # @option options [Proc] :callback The callback
            # @option options [Object] :default Default value returned when an error ocurred which was handled. 
            # @param [Array] args The arguments for the code block 
            # @param [#call] block The code block
            def initialize (options = Hash.new,*args, &block)
                unless block
                    raise ArgumentError, 'you must pass a work block to initialize a new Task.'
                end
                options = Kernel.validate_options(options,{:sync_key => nil,:default => nil,:callback => nil})
                @sync_key = options[:sync_key]
                @arguments = args
                @default = options[:default]
                @callback = options[:callback]
                @block = block
                @mutex = Mutex.new
                @pool = nil
                @state_temp = nil
                @state = nil
                @termination_signal = nil
                @termination_signals = Set.new
                reset
            end

            # Resets the tasks.
            # This can be used to requeue a task that is already finished
            def reset
                if finished? || !started?
                    @mutex.synchronize do
                        @result = @default
                        @state = :waiting
                        @exception = nil
                        @started_at = nil
                        @queued_at = nil
                        @stopped_at = nil
                    end
                else
                    raise RuntimeError,"cannot reset a task which is not finished"
                end
            end

            # returns true if the task has a default return vale
            # @return [Boolean]
            def default?
                 @mutex.synchronize do 
                     @default != nil
                 end
            end

            #sets all internal state to running
            #call execute after that.
            def pre_execute(pool=nil)
                @mutex.synchronize do 
                    #store current thread to be able to terminate
                    #the thread
                    @pool = pool
                    @thread = Thread.current
                    @started_at = Time.now
                    @state = :running
                end
            end

            # Executes the task.
            # Should be called from a worker thread after pre_execute was called.
            # After execute returned and the task was deleted 
            # from any internal list finalize must be called
            # to propagate the task state.
            def execute()
                raise RuntimeError, "call pre_execute ThreadPool::Task first. Current state is #{@state} but :running was expected" if @state != :running
                @state_temp = begin
                            @result = @block.call(*@arguments)
                            :finished
                        rescue Exception => e
                            @exception = e
                            if e.is_a? Asked
                                :terminated
                            else
                                :exception
                            end
                        end
                @stopped_at = Time.now
            end
            
            # propagates the tasks state
            # should be called after execute
            def finalize
                @mutex.synchronize do
                    @thread = nil
                    @state = @state_temp
                    @pool = nil
                end
                begin
                    @callback.call @result,@exception if @callback
                rescue Exception => e
                    ThreadPool.report_exception("thread_pool: in #{self}, callback #{@callback} failed", e)
                end
                notify_termination
            end

            # Terminates the task if it is running
            def terminate!(exception = Asked)
                @mutex.synchronize do
                    return unless running?
                    @state = :stopping
                    @thread.raise exception
                end
            end

            # Registers a signal to use to notify the caller that the task
            # finished
            #
            # @param [#broadcast] signal the object that will do the signalling
            #   (usually a {ConditionVariable} object). Set to nil if none is
            #   needed
            # @param [Mutex,nil] mutex a lock to acquire while signalling
            # @yield a context in which the mutex is taken and the signal
            #   registered
            #
            # As an example, see ThreadPool#wait
            def register_termination_notification(signal, mutex = nil, &block)
                @termination_signals << [signal, mutex]
                yield
            ensure
                @termination_signals.delete([signal, mutex])
            end

            # Notifies that the task has finished using the notification objects
            # registered with {register_termination_notification}
            #
            # This must be called in a context where the internal
            # synchronization mutex is finished
            def notify_termination
                signals = @mutex.synchronize do
                    signals, @termination_signals = @termination_signals, Array.new
                    signals
                end
                signals.each do |signal, mutex|
                    if mutex
                        mutex.synchronize { signal.broadcast }
                    else
                        signal.broadcast
                    end
                end
            end

            # Wait for this task to finish working
            #
            # @param [ConditionVariable,nil] signal the condition variable that
            #   should be used to notify the caller
            def wait
                @mutex.synchronize do
                    @termination_signal ||= ConditionVariable.new
                    register_termination_notification(@termination_signal, @mutex) do
                        return if finished?
                        while true
                            @termination_signal.wait(@mutex)
                            return if finished?
                        end
                    end
                end
            end

            # Called from the worker thread when the work is done 
            #
            # @yield [Object,Exception] The callback
            def callback(&block)
                @mutex.synchronize do
                    @callback = block
                end
            end

            # Returns the number of seconds the task is or was running
            # at the given point in time
            #
            # @param [Time] time The point in time.
            # @return[Float]
            def time_elapsed(time = Time.now)
                #no need to synchronize here
                if running?
                    (time-@started_at).to_f
                elsif finished?
                    (@stopped_at-@started_at).to_f
                else
                    0
                end
            end
        end

        # The minimum number of worker threads.
        #
        # @return [Integer]
        attr_reader :min

        # The maximum number of worker threads.
        #
        # @return [Integer]
        attr_reader :max

        # The number of worker threads that have been spawned so far
        #
        # @return [Integer]
        # @see waiting_threads
        def spawned_threads
            @mutex.synchronize do
                @workers.size
            end
        end

        def spawned
            spawned_threads
        end

        # The number of threads that are waiting for work
        #
        # @return [Integer]
        # @see spawned_threads
        def waiting_threads
            @mutex.synchronize do
                @waiting
            end
        end

        # The number of worker threads waiting for work.
        #
        # @return [Fixnum]
        attr_reader :waiting
        
        # The average execution time of a (running) task.
        #
        # @return [Float]
        attr_reader :avg_run_time
        
        # The average waiting time of a task before being executed.
        #
        # @return [Float]
        attr_reader :avg_wait_time

        # Auto trim automatically reduces the number of worker threads if there are too many
        # threads waiting for work.
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
            @cond_sync_key = ConditionVariable.new
            @mutex = Mutex.new

            @tasks_waiting = []         # tasks waiting for execution
            @tasks_running = []         # tasks which are currently running
            
            # Statistics
            @avg_run_time = 0           # average run time of a task in s [Float]
            @avg_wait_time = 0          # average time a task has to wait for execution in s [Float]

            @workers = []               # thread pool
            @waiting = 0
            @shutdown = false
            @callback_on_task_finished = nil
            @pipes = nil
            @sync_keys = Set.new

            @trim_requests = 0
            @auto_trim = false

            @mutex.synchronize do
                min.times do
                    spawn_thread
                end
            end
        end

        # sets the minimum number of threads
        def min=(val)
            resize(val,max)
        end

        # sets the maximum number of threads
        def max=(val)
            resize(min,val)
        end

        # returns the current used sync_keys
        def sync_keys
            @mutex.synchronize do
                @sync_keys.clone
            end
        end

        def clear
            shutdown
            join
        rescue Exception
        ensure
            @shutdown = false
        end

        # Checks if the thread pool is shutting down all threads.
        #
        # @return [boolean]
        def shutdown?; @shutdown; end

        # Disable all processing
        def disable_processing
            @__max, @__min = @max, @min
            resize(0, 0)
        end

        # Enable all processing
        def enable_processing
            resize(@__max, @__min)
        end

        # Changes the minimum and maximum number of threads
        #
        # @param [Fixnum] min the minimum number of threads
        # @param [Fixnum] max the maximum number of threads
        def resize (min, max = min)
            if max < min
                raise ArgumentError, "max number of threads (#{max}) is lower than min (#{min})"
            end

            @mutex.synchronize do
                @min, @max = min, max

                if @workers.size >= @max
                    too_many = (@workers.size - @max)
                    if @trim_requests != too_many
                        @trim_requests = too_many
                        if too_many > 0
                            @cond.broadcast
                        end
                    end
                else
                    threads_needed = [@max, @tasks_waiting.size + @workers.size].min
                    threads_needed = [@min, threads_needed].max
                    spawn_needed = [threads_needed - @workers.size, 0].max
                    spawn_needed.times do
                        spawn_thread
                    end
                end
            end
        end

        # Number of tasks waiting for execution
        # 
        # @return [Fixnum] the number of tasks
        def backlog
            @mutex.synchronize do
                @tasks_waiting.length
            end
        end

        # Number of tasks that are currently running
        def running
            @mutex.synchronize do
                @tasks_running.size
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
            process_with_options(nil,*args,&block)
        end

        # Returns true if a worker thread is currently processing a task 
        # and no work is queued
        #
        # @return [Boolean]
        def process?
            @mutex.synchronize do
                 waiting != @workers.size || @tasks_waiting.length > 0
            end
        end

        # Processes the given block as soon as the next thread is available
        # with the given options.
        #
        # @param (see Task#initialize)
        # @option (see Task#initialize)
        # @return [Task]
        def process_with_options(options,*args, &block)
            task = Task.new(options,*args, &block)
            self << task
            task
        end

        # Processes the given block from current thread but insures
        # that during processing no worker thread is executing a task
        # which has the same sync_key.
        #
        # This is useful for instance member calls which are not thread
        # safe.
        #
        # @param [Object] sync_key The sync key
        # @yield [*args] the code block block 
        # @return [Object] The result of the code block
        def sync(sync_key,*args,&block)
            raise ArgumentError,"no sync key" unless sync_key

            @mutex.synchronize do
                while(!@sync_keys.add?(sync_key))
                    @cond_sync_key.wait @mutex #wait until someone has removed a key
                end
            end
            begin
                result = block.call(*args)
            ensure
                @mutex.synchronize do
                    @sync_keys.delete sync_key
                end
                @cond_sync_key.signal
                @cond.signal # worker threads are just waiting for work no matter if it is
                # because of a deletion of a sync_key or a task was added
            end
            result
        end

        # Same as sync but raises Timeout::Error if sync_key cannot be obtained after
        # the given execution time.
        #
        # @param [Object] sync_key The sync key
        # @param [Float] timeout The timeout
        # @yield [*args] the code block block 
        # @return [Object] The result of the code block
        def sync_timeout(sync_key,timeout,*args,&block)
            raise ArgumentError,"no sync key" unless sync_key

            Timeout::timeout(timeout) do
                @mutex.synchronize do
                    while(!@sync_keys.add?(sync_key))
                        @cond_sync_key.wait @mutex #wait until someone has removed a key
                    end
                end
            end
            begin
                result = block.call(*args)
            ensure
                @mutex.synchronize do
                    @sync_keys.delete sync_key
                end
                @cond_sync_key.signal
                @cond.signal # worker threads are just waiting for work no matter if it is
                # because of a deletion of a sync_key or a task was added
            end
            result
        end

        # Processes the given {Task} as soon as the next thread is available
        # 
        # @param [Task] task The task.
        # @return [Task]
        def <<(task)
            if task.finished?
                task.reset
            elsif task.started?
                raise "cannot add task #{task} it is still running"
            end

            @mutex.synchronize do
                if shutdown? 
                    raise "unable to add work while shutting down"
                end
                task.queued_at = Time.now
                @tasks_waiting << task

                tasks_size = (@tasks_waiting.size + @tasks_running.size)
                while @workers.size < @max && @workers.size < tasks_size
                    spawn_thread
                end
                @cond.signal
            end
            task
        end

        # Shuts down all threads.
        #
        def shutdown()
            @mutex.synchronize do
                @shutdown = true
            end
            @cond.broadcast
        end

        # The current list of threads created by the pool
        #
        # It is a copy of the actual list, and can only be interpreted as a
        # "snapshot" of the actual list as the pool might change the list
        # between the call and the time you evaluate the list.
        def workers
            @mutex.synchronize do
                @workers.dup
            end
        end

        # Blocks until all threads were terminated.
        # This does not terminate any thread by itself and will block for ever
        # if shutdown was not called.
        def join
            while true
                if !@shutdown
                    raise ArgumentError, "#join called without calling #shutdown"
                end

                w = @mutex.synchronize do
                    @workers.first
                end
                return if !w
                w.join
            end
            self
        end

        # Given code block is called for every task which was
        # finished even it was terminated.
        #
        # This can be used to store the result for an event loop
        #
        # @yield [Task] the code block
        def on_task_finished (&block)
            @mutex.synchronize do
                @callback_on_task_finished = block
            end
        end

        def process_all_pending_work
            signal = ConditionVariable.new
            while true
                @mutex.synchronize do
                    all_tasks = @tasks_waiting + @tasks_running
                    return if all_tasks.empty?
                    all_tasks.first.register_termination_notification(signal, @mutex) do
                        signal.wait(@mutex)
                    end
                end
            end
        end

        private

        #calculates the moving average 
        def moving_average(current_val,new_val)
            return new_val if current_val == 0
            current_val * 0.95 + new_val * 0.05
        end

        def thread_find_one_task
            task, idx = @tasks_waiting.each_with_index.find do |t, _|
                !t.sync_key || @sync_keys.add?(t.sync_key)
            end
            if task
                @tasks_waiting.delete_at(idx)
                @tasks_running << task
                task
            end
        end

        # Waits for work to be available or thread termination
        #
        # If work is available, it acquires the task (calling
        # {Task#pre_execute}) and returns it
        #
        # It must be called with the main synchronization mutex taken
        #
        # @return [Task,nil] the task to be processed, or nil if the thread
        #   should be terminated
        def thread_get_work
            while !shutdown?
                if @trim_requests > 0
                    @trim_requests -= 1
                    return
                end

                if task = thread_find_one_task
                    task.pre_execute(self)
                    @avg_wait_time = moving_average(@avg_wait_time,
                                                    Time.now-task.queued_at)
                    return task
                end

                # Nothing to do ... check whether the thread should trim itself
                if auto_trim && @workers.size > @min
                    return
                end

                @waiting += 1
                @cond.wait @mutex
                @waiting -= 1
            end
        end

        def thread_execute_task(task)
            task.execute
        rescue Exception => e
            ThreadPool.report_exception(nil, e)
        ensure
            @mutex.synchronize do
                @tasks_running.delete task
                @sync_keys.delete(task.sync_key) if task.sync_key
                @avg_run_time = moving_average(
                    @avg_run_time,
                    task.stopped_at-task.started_at)
            end
            if task.sync_key
                @cond_sync_key.signal
                @cond.signal # maybe another thread is waiting for a sync key
            end
            task.finalize # propagate state after it was deleted from the internal lists
            @callback_on_task_finished.call(task) if @callback_on_task_finished
        end

        def thread_main_loop
            while true
                current_task = @mutex.synchronize do
                    thread_get_work
                end
                return if !current_task
                thread_execute_task(current_task)
            end
        end

        
        # spawns a worker thread
        # must be called from a synchronized block
        def spawn_thread
            thread = Thread.new do
                thread_main_loop

                @mutex.synchronize do
                    @workers.delete thread
                end
            end
            @workers << thread
        rescue Exception => e
            ThreadPool.report_exception(nil, e)
        end

        def self.report_exception(msg, e)
            if msg
                STDERR.puts msg
            end
            STDERR.puts e.message
            STDERR.puts "  #{e.backtrace.join("\n  ")}"
        end
    end
end
