require 'utilrb/thread_pool'
require 'utilrb/module/attr_predicate'
require 'utilrb/logger/root'

class Proc
    def pretty_print(pp)
        code = File.readlines(source_location[0])
        code_line = source_location[1]
        code_start = [code_line - 5, 0].max
        code[code_start, 10].each do |line|
            pp.breakable
            pp.text line.chomp
        end
    end
end

module Utilrb
    # Simple event loop which supports timers and defers blocking operations to
    # a thread pool those results are queued and being processed by the event
    # loop thread at the end of each step. 
    #
    # All events must be code blocks which will be executed at the end of each step.
    # There is no support for filtering or event propagations.
    #
    # For an easy integration of ruby classes into the event loop the {Forwardable#def_event_loop_delegator}
    # can be used.
    #
    # @example Example for using the EventLoop
    #   event_loop = EventLoop.new 
    #   event_loop.once do 
    #     puts "called once"
    #   end
    #
    #   event_loop.every(1.0) do 
    #     puts "called every second"
    #   end
    #
    #   callback = Proc.new |result|
    #     puts result 
    #   end
    #   event_loop.defer callback do
    #     sleep 2
    #     "result from the worker thread #{Thread.current}"
    #   end
    #
    #   event_loop.exec
    # 
    # @author Alexander Duda <Alexander.Duda@dfki.de>
    class EventLoop
        extend Logger::Root("Utilrb::EventLoop", Logger::INFO)
        include Logger::Hierarchy
        include Logger::Forward

        attr_predicate :trace?, true

        # Timer for the {EventLoop} which supports single shot and periodic activation
        #
        # @example
        #       loop = EventLoop.new
        #       timer = EventLoop.every(0.1) do 
        #                  puts 123
        #               end
        #       loop.exec
        class Timer
            attr_accessor :single_shot
            attr_accessor :period
            attr_accessor :event_loop
            attr_reader :result
            attr_accessor :doc

            # A timer
            #
            # @param [EventLoop] event_loop the {EventLoop} the timer belongs to
            # @param[Float] period The period of the timer in seconds.
            # @param[Boolean] single_shot if true the timer will fire only once
            # @param[#call] block The code block which will be executed each time the timer fires
            # @see EventLoop#once
            def initialize(event_loop,period=0,single_shot=false,&block)
                @block = block
                @event_loop = event_loop
                @last_call = Time.now
                @period = period
                @single_shot = single_shot
                @stopped = true
                @doc = Kernel.caller.find do |s|
                    !(%r"#{Regexp.quote(__FILE__)}"o =~ s) && !(s =~ /^\/usr\/.+/)
                end.to_s
            end

            # Cancels the timer. If it is not running it will do nothing
            def cancel
                @stopped = true
                @event_loop.cancel_timer self
            end

            def stopped?
                @stopped 
            end

            # Returns true if the timer is currently running.
            #
            # @return [boolean]
            def running?
                @event_loop.timer? self
            end

            # Starts the timer by adding itself to the EventLoop the timer
            # belongs to. If no period is given the one which was given during
            # initializing will be used.
            #
            # @param [Float] period The period in seconds
            # @param [TrueClass,FalseClass] instantly If set to true the timer instantly runs otherwise
            #   the timer waits until the first period passed.
            # @raise [ArgumentError] if no period is specified
            # @return [Timer]
            def start(period = @period, instantly = true, time = Time.now)
                cancel
                @stopped = false
                @period = period
                raise ArgumentError,"no period is given" unless @period
                @last_call = time
                if instantly
                    queue
                end
                @event_loop.add_timer self
                self
            end

            # Returns true if the timer should fire now. This is called by the
            # EventLoop to check if the timer elapsed.
            #
            # @param [Time] time The time used for checking
            # @return [Boolean}
            def timeout?(time = Time.now)
                time - @last_call > @period
            end

            # Returns true if the timer is a single shot timer.
            #
            # @return [Boolean}
            def single_shot?
                @single_shot == true
            end

            # Executes the code block tight to the timer and 
            # saves a time stamp.
            #
            # @param [Time] time The time stamp
            def call(time = Time.now)
                reset(time)
                @result = @block.call
            end

            # Resets the timer internal time to the given one.
            #
            # @param [Time] time the time
            def reset(time = Time.now)
                @last_call = time
            end

            # Queues this timer's execution for the next event loop
            def queue(_time = Time.now)
                @last_call = Time.at(0)
            end

            alias :stop :cancel
        end

        # A timer specialized for {EventLoop#async_every}
        class AsyncTimer < Timer
            # The thread pool task that actually does this timer's job
            attr_accessor :task

            def initialize(event_loop,period,task)
                super(event_loop,period)
                @completion_blocks = Array.new
                @task = task
            end

            # Queues this timer explicitely
            #
            # Unlike {Timer#queue}, the async work is scheduled right now. If
            # we're lucky, it will be available *before* the next event loop
            def queue(reset_time = Time.now)
                event_loop.thread_pool << task
                if reset_time
                    reset(reset_time)
                end
            end

            # Executes this timer explicitely
            def execute(reset_time = Time.now)
                event_loop.execute_async_timer(self)
                if reset_time
                    reset(reset_time)
                end
                if task.exception
                    raise task.exception
                else
                    task.result
                end
            end

            def finalize
                # Allow for the completion blocks to re-add themselves
                completion_blocks, @completion_blocks = @completion_blocks, Array.new
                completion_blocks.each do |block|
                    block.call
                end
            end

            # Execute the given block the next time this timer finished its
            # execution
            #
            # The block is executed in the event loop's context
            def on_completion(&block)
                @completion_blocks << block
            end

            # Wait for any pending execution to finish
            def wait
                task.wait
            end
        end

        # An event loop event
        class Event
            def initialize(block)
                @block = block
                @ignore = false
            end

            def call
                @block.call
            end


            def pretty_print(pp)
                pp.text "Utilrb::EventLoop::Event "
                pp.nest(2) do
                    pp.breakable
                    pp.text @block.to_s
                    @block.pretty_print(pp)
                end
            end

            # If called the event will be ignored and
            # removed from all internal event queues.
            def ignore!
                @ignore = true
            end
             
            def ignore?
                @ignore
            end
        end

        def self.cleanup_backtrace(&block)
            block.call
        rescue
            $@.delete_if{|s| %r"#{Regexp.quote(__FILE__)}"o =~ s}
            ::Kernel::raise
        end

        # Underlying thread pool used to defer work.
        #
        # @return [Utilrb::ThreadPool]
        attr_reader :thread_pool

        # A new EventLoop
        def initialize
            @mutex = Mutex.new
            @events = Queue.new               # stores all events for the next step
            @timers = Set.new                 # stores all timers
            @every_cylce_events = Set.new     # stores all events which are added to @events each step
            @on_error = {}                    # stores on error callbacks
            @errors = Queue.new               # stores errors which will be re raised at the end of the step
            @thread_pool = ThreadPool.new
            @thread = Thread.current #the event loop thread
            @stop = nil
        end

        # Integrates a blocking operation call into the EventLoop like {Utilrb::EventLoop#defer}
        # but has a more suitable syntax for deferring a method call
        #
        #    async method(:my_method) do |result,exception|
        #          if exception
        #                  raise exception
        #          else
        #                  puts result
        #          end
        #    end
        #
        # @param [#call] work The proc which will be deferred
        # @yield [result] The callback
        # @yield [result,exception] The callback
        # @return [Utilrb::ThreadPool::Task] The thread pool task.
        def async(work,*args,&callback)
            async_with_options(work,Hash.new,*args,&callback)
        end

        # (see #async)
        # @param [Hash] options The options
        # @option (see #defer)
        def async_with_options(work,options=Hash.new,*args,&callback)
            options[:callback] = callback
            defer(options,*args,&work)
        end

        # (see ThreadPool#sync)
        def sync(sync_key,*args,&block)
            thread_pool.sync(sync_key,*args,&block)
        end

        # (see ThreadPool#sync_timeout)
        def sync_timeout(sync_key,timeout,*args,&block)
            thread_pool.sync_timeout(sync_key,timeout,*args,&block)
        end

        def pretty_print(pp) # :nodoc:
            pp.text "EventLoop "
        end

        # Integrates a blocking operation call like {Utilrb::EventLoop#async}
        # but automatically re queues the call if period was passed and the
        # task was finished by the worker thread.  This means it will never re
        # queue the call if the task blocks for ever and it will never simultaneously
        # defer the call to more than one worker thread.
        #
        # @param [Hash] options The options 
        # @option options [Float] :period The period
        # @option options [Boolean] :start Starts the timer right away (default = true)
        # @param [#call] work The proc which will be deferred
        # @param (see #defer)
        # @option (see #defer)
        # @return [EventLoop::Timer] The thread pool task.
        def async_every(work,options=Hash.new,*args, &callback)
            options, async_opt = Kernel.filter_options options,
                period: nil, start: true, queue: true

            period = options[:period]
            raise ArgumentError,"No period given" unless period

            timer = nil # This is set later :(
            task = async_with_options(work, async_opt.merge(queue: false), *args) do |result, error|
                if callback.arity == 1 && !error
                    callback.call(result)
                else
                    ret = callback.call(result, error)
                end
                timer.finalize
                ret
            end

            timer = AsyncTimer.new(self,period,task) do
                if task.finished?
                    add_task task
                end
            end

            if options[:start]
                # We never set the 'instantly flag'. If queue is true, we simply
                # psas it to #async_with_options which will add it to the thread
                # pool right away
                timer.start(period, options[:queue])
            end
            timer
        end

        # Integrates a blocking operation call into the EventLoop by
        # executing it from a different thread. The given callback
        # will be called from the EventLoop thread while processing its events after
        # the call returned.
        #
        # If the callback has an arity of 2 the exception will be passed to the
        # callback as second parameter in an event of an error. The error is
        # also passed to the error handlers of the even loop, but it will not
        # be re raised if the error is marked as known
        #
        # To overwrite an error the callback can return :ignore_error or
        # a new instance of an error in an event of an error. In this
        # case the error handlers of the event loop will not be called
        # or called with the new error instance.
        #
        # @example ignore a error
        # callback = Proc.new do |r,e|
        #               if e
        #                  :ignore_error
        #               else
        #                  puts r
        #               end
        #            end 
        # defer({:callback => callback}) do
        #    raise
        # end
        #
        # @param [Hash] options The options 
        # @option (see ThreadPool::Task#initialize)
        # @option options [Proc] :callback The callback
        # @option options [class] :known_errors Known erros which will be rescued
        # @option options [Proc] :on_error Callback which is called when an error occured
        #
        # @param (see ThreadPool::Task#initialize)
        # @return [ThreadPool::Task] The thread pool task.
        def defer(options=Hash.new,*args,&block)
            options, task_options = Kernel.filter_options options,
                callback: nil,
                known_errors: Array.new,
                on_error:nil,
                queue: true

            callback = options[:callback]
            error_callback = options[:on_error]
            known_errors = Array(options[:known_errors])

            task = Utilrb::ThreadPool::Task.new(task_options,*args,&block)
            # ensures that user callback is called from main thread and not from worker threads
            if callback
                task.callback do |result,exception|
                    once do
                        if trace?
                            @mutex.synchronize do
                                info "processing callback(#{result},#{exception})"
                                log_pp :info, callback
                            end
                        end

                        if callback.arity == 1
                            callback.call result if !exception
                        else
                            e = callback.call result,exception
                            #check if the error was overwritten in the
                            #case of an error
                            exception = if exception
                                            if e.is_a?(Symbol) && e == :ignore_error
                                                nil
                                            elsif e.is_a? Exception
                                                # If the new exception has no
                                                # backtrace, propagate the one
                                                # that we already have
                                                if !e.backtrace || e.backtrace.empty?
                                                    e.set_backtrace(exception.backtrace)
                                                end
                                                e
                                            else
                                                exception
                                            end
                                        end
                        end
                        if exception
                            error_callback.call(exception) if error_callback
                            raises = !known_errors.any? {|error| exception.is_a?(error)}
                            handle_error(exception,raises)
                        end
                    end
                end
            else
                task.callback do |result,exception|
                    if exception
                        raises = !known_errors.find {|error| exception.is_a?(error)}
                        once do
                            error_callback.call(exception) if error_callback
                            handle_error(exception,raises)
                        end
                    end
                end
            end
            if options[:queue]
                @thread_pool << task
            end
            task
        end

        # Executes the given block in the next step from the event loop thread.
        # Returns a Timer object if a delay is set otherwise an handler to the
        # Event which was queued.
        #
        # @yield [] The code block.
        # @return [Utilrb::EventLoop::Timer,Event]
        def once(delay=nil,&block)
            raise ArgumentError "no block given" unless block
            if delay && delay > 0
                timer = Timer.new(self,delay,true,&block)
                timer.start(delay,false)
            else
                add_event(Event.new(block))
            end
        end

        # Calls the give block in the event loop thread. If the current thread
        # is the event loop thread it will execute it right a way and returns
        # the result of the code block call. Otherwise, it returns an handler to 
        # the Event which was queued.
        #
        #@return [Event,Object]
        def call(&block)
            if thread?
                block.call
            else
                once(&block)
            end
        end

        # Returns true if events are queued.
        #
        # @return [Boolean]
        def events?
            !@events.empty? || !@errors.empty?
        end

        # Returns true if the next call to {step} will process something
        #
        # @param [Time] time the logical processing time at which timers should
        #   be evaluated
        #
        # @return [Boolean]
        def has_pending_work?(time = Time.now)
            events? || @timers.any? { |t| t.timeout?(time) }
        end

        # Adds a timer to the event loop which will execute 
        # the given code block with the given period from the
        # event loop thread.
        #
        # @param [Numeric] period period of the timer in seconds
        # @param [Hash] options
        # @option options [Boolean] start (true) enables the timer right away,
        #   otherwise, this method is really equivalent to calling Timer.new
        # @option options [Boolean] queue (true) if true, the timer's block will
        #   be processed in the next event loop. Otherwise, after the first
        #   period passed. This option has no effect if start is false.
        # @yield a code block that should be executed periodically
        # @return [Timer]
        def every(period,options = Hash.new,&block)
            # Backward compatibility
            if !options.kind_of?(Hash)
                options = Hash[start: !!options]
            end
            options = Kernel.validate_options options,
                start: true, queue: true

            timer = Timer.new(self,period,&block)
            if options[:start]
                timer.start(period,options[:queue])
            end
            timer
        end

        # Executes the given block every step from the event loop thread.
        #
        # @return [Event] The event
        def every_step(&block)
            add_event Event.new(block),true
        end

        # Errors caught during event loop callbacks are forwarded to
        # registered code blocks. The code block is called from
        # the event loop thread.
        #
        # @param @error_class The error class the block should be called for
        # @yield [exception] The code block
        def on_error(error_class,&block)
            @mutex.synchronize do
                @on_error[error_class] ||= []
                @on_error[error_class]  << block
            end
        end

        # Errors caught during event loop callbacks are forwarded to
        # registered code blocks. The code blocks are called from 
        # the event loop thread.
        #
        # @param @error_classes The error classes the block should be called for
        # @yield [exception] The code block
        def on_errors(*error_classes,&block)
            error_classes.flatten!
            error_classes.each do |error_class|
                on_error(error_class,&block)
            end
        end

        # Raises if the current thread is not the event loop thread (by default
        # the one the event loop was started from).
        #
        # @raise [RuntimeError]
        def validate_thread
            raise "current thread is not the event loop thread" if !thread?
        end

        # Returns true if the current thread is the 
        # event loop thread.
        #
        # @return [Boolean]
        def thread?
            @mutex.synchronize do
                if Thread.current == @thread
                    true
                else
                    false
                end
            end
        end

        # Sets the event loop thread. By default it is set to the one
        # the EventLoop was started from.
        #
        # @param[Thread] thread The thread
        def thread=(thread)
            @mutex.synchronize do
                @thread = thread
            end
        end

        # Returns true if the given timer is running.
        #
        # @param [Timer] timer The timer.
        # @return [Boolean]
        def timer?(timer)
            @mutex.synchronize do
                @timers.include? timer
            end
        end

        # Returns all currently running timers.
        #
        # @return Array<Timer>
        def timers
            @mutex.synchronize do
                @timers.dup
            end
        end

        # Cancels the given timer if it is running otherwise
        # it does nothing.
        # 
        # @param [Timer] timer The timer
        def cancel_timer(timer)
            @mutex.synchronize do
                @timers.delete timer
            end
        end

        # Resets all timers to fire not before their hole 
        # period is passed counting from the given point in time.
        #
        # @param [Time] time The time
        def reset_timers(time = Time.now)
            @mutex.synchronize do 
                @timers.each do |timer|
                    timer.reset time
                end
            end
        end

        # Starts the event loop with the given period. If a code
        # block is given it will be executed at the end of each step.
        # This method will block until stop is called
        #
        # @param [Float] period The period
        # @yield The code block
        def exec(period=0.05,&block)
            @stop = false
            reset_timers
            periodic_loop(period) do
                return if @stop
                step(Time.now,&block)
            end
        end

        # Stops the EventLoop after [#exec] was called.
        def stop
            @stop = true
        end

        # Steps with the given period until the given 
        # block returns true.
        #
        # @param [Float] period The period 
        # @param [Float] timeout The timeout in seconds
        # @yieldreturn [Boolean]
        def wait_for(period=0.05,timeout=nil,&block)
            time = Time.now
            periodic_loop(period, timeout) do
                if process_all_pending_work(time,
                        wait_for_threads: true,
                        exit_condition: block)
                    return
                end
            end
        end

        # Generic implementation of a periodic loop
        #
        # @param [Numeric] period the period in seconds
        # @param [Numeric] timeout the timeout in seconds
        def periodic_loop(period, timeout = nil)
            if timeout
                timeout = Time.now + timeout
            end
            while true
                cycle_time = Time.now
                if timeout && (cycle_time > timeout)
                    return
                end

                yield

                # No point in sleeping for the next period ... we're going to
                # hit the timeout anyway
                if timeout && (cycle_time + period > timeout)
                    return
                end

                diff = Time.now-cycle_time
                sleep(period-diff) if diff < period
            end
        end

        # Steps with the given period until all
        # worker thread are waiting for work
        #
        # @param [Float] period Ther period
        # @param (@see #step)
        def steps(period = 0.05,max_time=1.0,&block)
            start = Time.now
            begin
                last_step = Time.now
                step(last_step,&block)
                time = Time.now
                break if max_time && max_time <= (time-start).to_f
                diff = (time-last_step).to_f
                sleep(period-diff) if diff < period && !@stop
            end while (thread_pool.process? || events?)
        end

        # (see ThreadPool#backlog)
        def backlog
            thread_pool.backlog
        end

        # Shuts down the thread pool
        def shutdown()
            thread_pool.shutdown()
        end

        def reraise_error(error)
            raise error, error.message, error.backtrace + caller(1)
        end

        # Executes a timer "as-if" it was scheduled normally
        def execute_async_timer(timer)
            # This one is tricky ... I hope I got it right
            #
            # The first thing we really need to do if flush the event loop. Any
            # that has been schedule before now has to be processed to ensure
            # that we're in the state the caller expects us to be in.  We don't
            # process every_cycle / timers, as they can't be meaningful w.r.t.
            # what the timer we want to execute (the order in their case is not
            # guaranteed)
            #
            # Then we can actually execute the timer's asynchronous task
            #
            # *Then* we need to execute the timer's completion callbacks. For
            # now, let's be content with re-flushing the event queue. A better
            # option would be to be able to process only the callback.
            #
            # Note that #sync_task will raise the exception raised by the task's
            # work block, so no need to flush the exceptions from the event
            # queue

            process_events(false)
            thread_pool.sync_task(timer.task)
            timer.finalize
            process_events(false)
        end

        # Execute a single event
        def process_event(event)
            if !event.ignore?
                if trace?
                    @mutex.synchronize do
                        info "executing"
                        log_pp(:info, event)
                    end
                end
                handle_errors{event.call}
            end
        end

        # Execute the events registered by {every_cycle}
        def process_every_cycle_events
            events = @mutex.synchronize do
                @every_cylce_events.delete_if(&:ignore?)
                @every_cylce_events.dup
            end
            events.each do |ev|
                process_event(ev)
            end
        end

        # Execute the single-shot events registered with {add_event}
        #
        # @param [Boolean] process_new_events if true, new events
        #   that are added while processing get processed as well. If false,
        #   only the events that have been queued before the call of this method
        #   are processed.
        def process_events(process_new_events)
            if process_new_events
                max = @events.size
            end

            counter = 0
            while !max || max > counter
                event = @events.pop(true)
                process_event(event)
                counter += 1
            end
        rescue ThreadError
        end

        # Execute the timers
        def process_timers(time)
            timers = @mutex.synchronize do
                timed_out = Array.new
                @timers.delete_if do |timer|
                    if !timer.stopped? && timer.timeout?(time)
                        timed_out << timer
                        timer.single_shot?
                    end
                end
                timed_out
            end
            timers.each do |timer|
                if trace?
                    info "executing timer #{timer}"
                end
                handle_errors{timer.call(time)}
            end
        end

        def with_error_handling
            reraise_error(@errors.shift) if !@errors.empty?
            yield
            reraise_error(@errors.shift) if !@errors.empty?
        end

        # Handles all current events and timers. If a code
        # block is given it will be executed at the end.
        #
        # @param [Time] time The time the step is executed for.
        # @yield The code block
        def step(time = Time.now,options=Hash.new,&block)
            options = Kernel.validate_options options,
                process_every: true
            validate_thread

            with_error_handling do
                process_events(false)
                process_every_cycle_events
                process_timers(time)
            end
            
            #allow thread pool to take over
            Thread.pass
        end

        # Wait for all the async work currently queued to finish processing
        #
        # This does not call {step}, so if you want the async processing
        # callbacks to be execxuted you must call step explicitly just after
        def process_all_async_work
            thread_pool.process_all_pending_work
        end

        # Process all events that can be processed until none are left
        #
        # @param [Hash] options
        # @option options [Boolean] wait_for_threads (false) if true, the loop
        #   will wait for all threads in the thread pool to finish all pending
        #   work before returning
        # @option options [#call] exit_condition a block that will be used to
        #   terminate the processing early. The block should return true if the
        #   exit condition is reached and false otherwise
        # @return[Boolean] true if the exit condition was reached and false if
        #   the call terminated because all pending work has been performed.
        def process_all_pending_work(time = Time.now, options = Hash.new)
            validate_thread
            options = Kernel.validate_options options,
                wait_for_threads: false,
                exit_condition: proc { false }
            exit_condition = options[:exit_condition]

            cycle, subcycle = 0, 0

            # Start pumping by executing a full step
            with_error_handling do
                if trace?
                    info "process_all_pending_work: executing initial cycle #{cycle}.#{subcycle}"
                end
                log_nest(2) do
                    process_events(true)
                    process_every_cycle_events
                    process_timers(time)
                end
            end

            while true
                cycle, subcycle = cycle + 1, 0
                while has_pending_work?(time)
                    if exit_condition.call
                        return true
                    end

                    if trace?
                        info "process_all_pending_work: executing #{cycle}.#{subcycle}"
                    end

                    with_error_handling do
                        log_nest(2) do
                            process_events(true)
                            process_timers(time)
                        end
                    end
                    subcycle += 1
                end

                if exit_condition.call
                    return true
                end

                if options[:wait_for_threads]
                    if trace?
                        info "process_all_pending_work: waiting for #{thread_pool.backlog + thread_pool.running} tasks to queue more work after #{cycle}.#{subcycle}"
                    end
                    thread_pool.wait_for do
                        # A thread finished and queued some work in the meantime
                        has_pending_work?(time)
                    end
                end

                if exit_condition.call
                    return true
                elsif !has_pending_work?(time)
                    return false
                end
            end
        ensure
            if trace?
                info "process_all_pending_work: done"
            end
        end

        # Adds a timer to the event loop
        #
        # @param [Timer] timer The timer.
        def add_timer(timer)
            @mutex.synchronize do
                raise "timer #{timer}:#{timer.doc} was already added!" if @timers.include?(timer)
                @timers << timer
            end
        end

        # Adds an Event to the event loop
        #
        # @param [Event] event The event
        # @param [Boolean] every_step Automatically added for every step
        def add_event(event,every_step = false)
            raise ArgumentError "cannot add event which is ignored." if event.ignore?
            if trace?
                @mutex.synchronize do
                    info "adding #{event}"
                    log_pp(:info, event)
                end
            end
            if every_step
                @mutex.synchronize do
                    @every_cylce_events << event
                end
            else
                @events << event
            end
            event
        end

        # Adds a task to the thread pool
        #
        # @param [ThreadPool::Task] task The task.
        def add_task(task)
            thread_pool << task
        end

        # Clears all timers, events and errors
        def clear
            thread_pool.clear

            @errors.clear
            @events.clear
            @mutex.synchronize do
                @every_cylce_events.clear
                @timers.clear
            end
        end

        # Clears all errors which occurred during the last step and are not marked as known 
        # If the errors were not cleared they are re raised the next time step is called.
        def clear_errors
            @errors.clear
        end

        def handle_error(error,save = true)
            call do
                on_error = @mutex.synchronize do
                    @on_error.find_all{|key,e| key === error}.map(&:last).flatten
                end
                on_error.each do |handler|
                    handler.call error
                end
                @errors << error if save == true
            end
        end

    private
        # Calls the given block and rescues all errors which can be handled
        # by the added error handler. If an error cannot be handled it is 
        # stored and re raised after all events and timers are processed. If
        # more than one error occurred which cannot be handled they are stored 
        # until the next step is called and re raised until all errors are processed.
        #
        # @info This method must be called from the event loop thread, otherwise
        #    all error handlers would be called from the wrong thread
        #
        # @yield The code block.
        # @see #error_handler
        def handle_errors(&block)
            block.call
        rescue Exception => e
            handle_error(e,true)
        end

    public
        # The EventLoop::Forwardable module provides delegation of specified methods to
        # a designated object like the ruby ::Forwardable module but defers the
        # method call to a thread pool of an event loop if a callback is given.
        # After the call returned the callback is called from the event loop thread
        # while it is processing its event at the end of each step.
        #
        # To ensure thread safety for all kind of objects the event loop defers
        # only one method call per object in parallel even if the method is
        # called without any callback. For this mechanism a sync key is used
        # which is by default the designated object but can be set to any
        # custom ruby object. If a method call is thread safe the sync key can
        # be set to nil allowing the event loop to call it in parallel while
        # another none thread safe method call of the designated object is processed.
        #
        # @note It is not possible to delegate methods where the target method needs
        #    a code block.
        #
        # @author Alexander Duda <Alexander.Duda@dfki.de>
        module Forwardable
            # Runtime error raised if the designated object is nil
            # @author Alexander Duda <Alexander.Duda@dfki.de>
            class DesignatedObjectNotFound < RuntimeError; end

            # Defines a method as delegator instance method with an optional alias
            # name ali.
            #
            # Method calls to ali will be delegated to accessor.method. If an error occurres
            # during proccessing it will be raised like in the case of the original object but
            # also forwarded to the error handlers of event loop.
            #
            # Method calls to ali(*args,&block) will be delegated to
            # accessor.method(*args) but called from a thread pool.  Thereby the code
            # block is used as callback called from the main thread after the
            # call returned. If an error occurred it will be:
            #  * given to the callback as second argument 
            #  * forwarded to the error handlers of the event loop
            #  * raised at the beginning of the next step if not marked as known error
            #
            # To overwrite an error the callback can return :ignore_error or a
            # new instance of an error. In an event of an error the error handlers of the
            # event loop will not be called or called with the new error
            # instance.
            #
            #    ali do |result,exception|
            #       if exception
            #           MyError.new
            #       else
            #          puts result
            #       end
            #    end
            #
            #    ali do |result,exception|
            #       if exception 
            #           :ignore_error
            #       else
            #          puts result
            #       end
            #    end
            #
            # If the callback accepts only one argument 
            # the callback will not be called in an event of an error but
            # the error will still be forwarded to the error handlers.
            #    
            # If the result shall be filtered before returned a filter method can
            # be specified which is called from the event loop thread just before
            # the result is returned.
            #
            # @example
            #       class Dummy
            #           # non thread safe method
            #           def test(wait)
            #               sleep wait
            #               Thread.current
            #           end
            #
            #           # thread safe method
            #           def test_thread_safe(wait)
            #               sleep wait
            #               Thread.current
            #           end
            #       end
            #       class DummyAsync
            #           extend Utilrb::EventLoop::Forwardable
            #           def_event_loop_delegator :@obj,:@event_loop,:test,:alias => :atest
            #           def_event_loop_delegator :@obj,:@event_loop,:test_thread_safe,:sync_key => false
            #
            #           def initialize(event_loop)
            #               @event_loop = event_loop
            #               @obj = Dummy.new
            #           end
            #       end
            #
            #       event_loop = EventLoop.new
            #       test = DummyAsync.new(event_loop)
            #       puts test.atest 2
            #       test.atest 2 do |result|
            #           puts result
            #       end
            #       test.thread_safe 2 do |result|
            #           puts result
            #       end
            #       sleep(0.1)
            #       event_loop.step
            #
            # @param [Symbol] accessor The symbol for the designated object.
            # @param [Symbol] event_loop The event loop accessor.
            # @param [Symbol] method The method called on the designated object.
            # @param [Hash] options The options
            # @option options [Symbol] :alias The alias of the method
            # @option options [Symbol] :sync_key The sync key 
            # @option options [Symbol] :filter The filter method
            # @option options [Symbol] :on_error Method which is called if an error occured
            # @option options [class] :known_errors Known errors which will be rescued but still be forwarded.
            # @see #sync
            def def_event_loop_delegator(accessor,event_loop, method, options = Hash.new )
                Forward.def_event_loop_delegator(self,accessor,event_loop,method,options)
            end

            def def_event_loop_delegators(accessor,event_loop, *methods)
                Forward.def_event_loop_delegators(self,accessor,event_loop,*methods)
            end

            def forward_to(accessor,event_loop,options = Hash.new,&block)
                obj = Forward.new(self,accessor,event_loop,options)
                obj.instance_eval(&block)
            end

        private
            class Forward
                def initialize(klass,accessor,event_loop,options = Hash.new)
                    @klass = klass
                    @stack = [options]
                    @accessor = accessor
                    @event_loop = event_loop
                end

                def options(options = Hash.new,&block)
                    @stack << @stack.last.merge(options)
                        block.call
                    @stack.pop
                end

                def thread_safe(&block)
                    options :sync_key => nil do 
                        block.call
                    end
                end

                def def_delegators(*methods)
                    options = if methods.last.is_a? Hash
                                  methods.pop
                              else
                                  Hash.new
                              end
                    methods << @stack.last.merge(options)
                    Forward.def_event_loop_delegators(@klass,@accessor,@event_loop,*methods)
                end

                def def_delegator(method,options = Hash.new)
                    options = @stack.last.merge options
                    Forward.def_event_loop_delegator(@klass,@accessor,@event_loop,method,options)
                end


                def self.def_event_loop_delegator(klass,accessor,event_loop, method, options = Hash.new )
                    options = Kernel.validate_options options,
                        filter: nil,
                        alias: method,
                        sync_key: :accessor,
                        known_errors: nil,
                        on_error: nil

                    raise ArgumentError, "accessor is nil" unless accessor
                    raise ArgumentError, "event_loop is nil" unless event_loop
                    raise ArgumentError, "method is nil" unless method

                    ali = options[:alias]
                    return if klass.instance_methods.include? ali.to_sym

                    filter = options[:filter]
                    sync_key = options[:sync_key]
                    sync_key ||= :nil
                    errors = "[#{Array(options[:known_errors]).map(&:name).join(",")}]"
                    on_error = options[:on_error]

                    line_no = __LINE__; str = %Q{
                    def #{ali}(*args, &block)
                        accessor,error = #{if options[:known_errors]
                                            %Q{
                                                begin
                                                    #{accessor} # cache the accessor.
                                                rescue #{Array(options[:known_errors]).join(",")} => e
                                                   [nil,e]
                                                end
                                               }
                                          else
                                                accessor.to_s
                                          end}
                        if !accessor
                            error ||= DesignatedObjectNotFound.new 'designated object is nil'
                            raise error
                        end

                        if !block
                            begin
                                result = #{sync_key != :nil ? "#{event_loop}.sync(#{sync_key}){accessor.__send__(:#{method}, *args)}" : "accessor.__send__(:#{method}, *args)"}
                                #{filter ? "#{filter}(result)" : "result"}
                            rescue Exception => error
                                #{"#{on_error}(error)" if on_error}
                                raise error
                            end
                        else
                            work = Proc.new do |*callback_args|
                                    acc,err = #{accessor} # cache accessor
                                    if !acc
                                        if err
                                            raise err
                                        else
                                            raise DesignatedObjectNotFound,'designated object is nil'
                                        end
                                    else
                                        acc.__send__(:#{method}, *callback_args)
                                    end
                                end
                            callback = #{filter ? "block.to_proc.arity == 2 ? Proc.new { |r,e| block.call(#{filter}(r),e)} : Proc.new {|r| block.call(#{filter}(r))}" : "block"}
                            #{event_loop}.async_with_options(work,
                                                             {:sync_key => #{sync_key},:known_errors => #{errors},
                                                             :on_error => #{ on_error ? "self.method(#{on_error.inspect})" : "nil" }},
                                                             *args, &callback)
                        end
                      rescue Exception
                        $@.delete_if{|s| %r"#{Regexp.quote(__FILE__)}"o =~ s}
                        ::Kernel::raise
                    end
                    }
                    # If it's not a class or module, it's an instance
                    begin
                        klass.module_eval(str, __FILE__, line_no)
                    rescue
                        klass.instance_eval(str, __FILE__, line_no)
                    end
                end

                # Defines multiple method as delegator instance methods 
                # @see #def_event_loop_delegator
                def self.def_event_loop_delegators(klass,accessor,event_loop, *methods)
                    methods.flatten!
                    options = if methods.last.is_a? Hash
                                  methods.pop
                              else
                                  Hash.new
                              end
                    raise ArgumentError, ":alias is not supported when defining multiple methods at once." if options.has_key?(:alias)
                    methods.each do |method|
                        def_event_loop_delegator(klass,accessor,event_loop,method,options)
                    end
                end
            end
        end
    end
end
