require 'utilrb/thread_pool'


module Utilrb
    # Simple event loop which supports timers and defers blocking operations to
    # a thread pool those results are queued and being processed by the event
    # loop thread at the end of each step.
    #
    # All events must be code blocks which will be executed at the end of each step.
    # There is no support for filtering or event propagations.
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
    class EventLoop
        private

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

            # A timer
            #
            # @param [EventLoop] event_loop the {EventLoop} the timer belongs to
            # @param[Float] period The period of the timer in seconds.
            # @param[Boolean] single_shot if true the timer will fire only once
            # @param[Proc] block The code block which will be executed each time the timer fires
            # @see EventLoop#once
            def initialize(event_loop,period=nil,single_shot=false,&block)
                @block = block
                @event_loop = event_loop
                @last_call = Time.now
                @period = period
                @single_shot = single_shot
            end

            # Cancels the timer. If it is not running it will do nothing
            def cancel
                @event_loop.cancel_timer self
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
            # @raise [ArgumentError] if no period is specified
            # @return [Timer]
            def start(period = @period)
                @period = period
                raise ArgumentError,"no period is given" unless @period
                @event_loop << self
                self
            end

            # Returns true if the timer should fire now. This is called by the
            # EventLoop to check if the timer elapsed.
            #
            # @param [Time] time The time used for checking
            # @return [Boolean}
            def timeout?(time = Time.now)
                if(time-@last_call).to_f >= @period
                    true
                else
                    false
                end
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
                @last_call = time
                @block.call
            end

            # Resets the timer internal time to the given one.
            #
            # @param [Time] the time
            def reset(time = Time.now)
                @last_call = time
            end
        end

        # Error class which will be raised if a deferred operation calls 
        # raises an error.
        class EventLoopError < RuntimeError
            attr_reader :error
            attr_reader :object

            def initialize(message,object,error)
                super message
                @object = object
                @error = error
            end
        end

        public
        # Underlying thread pool used to defer work.
        #
        # @return [Utilrb::ThreadPool]
        attr_reader :thread_pool

        # A new EventLoop
        def initialize
            @mutex = Mutex.new
            @events = []
            @timers = []
            @every_cylce_events = []
            @error_handlers = []
            @errors = []
            @thread_pool = ThreadPool.new
        end

        # Integrates a blocking operation call into the EventLoop by
        # executing it in a different thread. The given callback and error_handler 
        # are called from the EventLoop thread during the next step after the
        # operation was finished.
        #
        # @overload defer(*args,&block)
        # @overload defer(callback,*args,&block)
        # @overload defer(callback,error_handler,*args,&block)
        # @param [Proc] callback The callback which is called when the work is done.
        # @param [Proc] error_handler Error handler which is called when an error is raised.
        # @yield [*args] The code block deferred to a worker thread
        #
        # @return [ThreadPool::Task] The thread pool task.
        def defer(callback=nil,error_handler=nil,*args,&block)
            #implements overload 
            if callback && !callback.respond_to?(:call)
                args = Array(callback) + Array(error_handler) + args
                callback = nil
                error_handler = nil
            elsif error_handler && !error_handler.respond_to?(:call)
                args = Array(error_handler) + args
                error_handler = nil
            end

            task = Utilrb::ThreadPool::Task.new(*args,&block)
            if callback
                task.callback do |result|
                    once do
                        callback.call result
                    end
                end
            end
            task.error_handler do |error|
                once do
                    if !error_handler || !error_handler.call(error)
                        raise EventLoopError.new("",task,error)
                    end
                end
            end
            @thread_pool << task
            task
        end

        # Executes the given block in the next step.
        #
        # @param [Proc] block The code block.
        def once(delay=nil,&block)
            if delay && delay > 0
                timer = Timer.new(self,delay,true,&block)
                timer.start
            else
                @mutex.synchronize do
                    @events << block
                end
            end
        end

        # Adds a timer to the event loop which will execute 
        # the given code block with the given period
        #
        # @param [period] period The period of the timer in seconds
        # @param [Boolean] single_shot If set to true, the timer is executed only once.
        # @param [Proc] block The code block.
        # @return [Timer]
        def every(period,&block)
            timer = Timer.new(self,period,&block)
            timer.start
        end

        # Executes the given block every step
        def every_step(&block)
            @mutex.synchronize do
                @every_cylce_events << block
            end
        end

        # Errors caught during event loop callbacks are forwarded to
        # all registered error handlers until one returns true. If no
        # handler can be found the error is re-raised.
        #
        # @yield [Exception] The code block
        def error_handler(&block)
            @mutex.synchronize do
                @error_handlers << block
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
        def reset_timer(time = Time.now)
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
            reset_timer
            while !@stop
                last_step = Time.now
                step(last_step,&block)
                diff = (Time.now-last_step).to_f
                sleep(period-diff) if diff < period
            end
        end

        # Stops the EventLoop after [#exec] was called.
        def stop
            @stop = true
        end

        # Handles all current events and timers. If a code
        # block is given it will be executed at the end.
        #
        # @param [Time] time The time the step is executed for.
        # @yield The code block
        def step(time = Time.now,&block)
            @mutex.synchronize do
                raise @errors.shift if !@errors.empty?

                @events += @every_cylce_events
                # process all events 
                @events.each do |event|
                    handle_errors{event.call}
                end
                @events.clear

                # check all timers and delete 
                # single shot timer if called
                @timers = @timers.find_all do |timer|
                    if !timer.timeout?(time)
                        true
                    else
                        handle_errors{timer.call(time)}
                        !timer.single_shot?
                    end
                end

                handle_errors{block.call} if block
                raise @errors.shift if !@errors.empty?
            end
        end

        # Adds an object to the event loop 
        #
        # @overload <<(proc)
        #   @param [Proc] If arity = 0 it will be forwarded to [#once] otherwise to [#error_handler]
        #   @raise [ArgumentError] if arity > 1 or argument is not a [Proc]
        # @overload <<(timer)
        #   @param [Timer] timer The timer which will be added 
        #   @raise [ArgumentError] if argument is not a [Timer]
        def <<(object,&block)
            self << block if block
            if object
                if object.is_a? Timer
                    @mutex.synchronize do
                        @timers << object unless @timers.include? object
                    end
                elsif object.is_a? Proc
                    if object.arity == 0
                        once(nil,&object)
                    elsif object.arity == 1
                        error_handler(&object)
                    else
                        raise ArgumentError
                    end
                else
                    raise ArgumentError
                end
            end
        rescue ArgumentError => e
            raise ArgumentError, "Do not know how to add #{object} to the event loop."
        end

        
        # Clears all errors which occurred during the last step and cannot be
        # handled by the error handlers. If the errors were not cleared they are
        # re raised the next time raise is called.
        def clear_errors
            @mutex.synchronize do
                @errors.clear
            end
        end

        private

        # Calls the given block and rescues all errors which can be handled
        # by the added error handler. If an error cannot be handled it is 
        # stored and re raised after all events and timers are processed. If
        # more than one error occurred which cannot be handled they are stored 
        # until the next step is called and re raised until all errors are processed.
        #
        # @yield The code block.
        # @see #error_handler
        def handle_errors(&block)
            block.call
        rescue Exception => e
            handler = @error_handlers.find do |handler|
                handler.call e
            end
            @errors << e unless handler
        end
    end
end
