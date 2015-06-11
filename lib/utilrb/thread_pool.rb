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
            end

            # Terminates the task if it is running
            def terminate!(exception = Asked)
                @mutex.synchronize do
                    return unless running?
                    @state = :stopping
                    @thread.raise exception
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
            @spawned = 0
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
            process_with_options(nil,*args,&block)
        end

        # Returns true if a worker thread is currently processing a task 
        # and no work is queued
        #
        # @return [Boolean]
        def process?
            @mutex.synchronize do
                 waiting != spawned || @tasks_waiting.length > 0
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
            raise "cannot add task #{task} it is still running" if task.thread
            task.reset if task.finished?
            @mutex.synchronize do
                if shutdown? 
                    raise "unable to add work while shutting down"
                end
                task.queued_at = Time.now
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
        def shutdown()
            tasks = nil
            @mutex.synchronize do
                @shutdown = true
            end
            @cond.broadcast
        end


        # Blocks until all threads were terminated.
        # This does not terminate any thread by itself and will block for ever
        # if shutdown was not called.
        def join
            @workers.first.join until @workers.empty?
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

        private

        #calculates the moving average 
        def moving_average(current_val,new_val)
            return new_val if current_val == 0
            current_val * 0.95 + new_val * 0.05
        end
        
        # spawns a worker thread
        # must be called from a synchronized block
        def spawn_thread
            thread = Thread.new do
                while !shutdown? do
                    current_task = @mutex.synchronize do
                        while !shutdown?
                            task = @tasks_waiting.each_with_index do |t,i|
                                if !t.sync_key || @sync_keys.add?(t.sync_key)
                                    @tasks_waiting.delete_at(i)
                                    t.pre_execute(self) # block tasks so that no one is using it at the same time
                                    @tasks_running << t
                                    @avg_wait_time = moving_average(@avg_wait_time,(Time.now-t.queued_at))
                                    break t
                                end
                            end
                            break task unless task.is_a? Array

                            if @trim_requests > 0
                                @trim_requests -= 1
                                break
                            end
                            @waiting += 1
                            @cond.wait @mutex
                            @waiting -= 1
                        end or break
                    end or break
                    begin
                        current_task.execute
                    rescue Exception => e
                        ThreadPool.report_exception(nil, e)
                    ensure
                        @mutex.synchronize do
                            @tasks_running.delete current_task
                            @sync_keys.delete(current_task.sync_key) if current_task.sync_key
                            @avg_run_time = moving_average(@avg_run_time,(current_task.stopped_at-current_task.started_at))
                        end
                        if current_task.sync_key
                            @cond_sync_key.signal
                            @cond.signal # maybe another thread is waiting for a sync key
                        end
                        current_task.finalize # propagate state after it was deleted from the internal lists
                        @callback_on_task_finished.call(current_task) if @callback_on_task_finished
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
