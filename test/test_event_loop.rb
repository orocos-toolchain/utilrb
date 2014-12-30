require 'utilrb/test'
require 'utilrb/event_loop'
require 'minitest/spec'

module TimeHelpers
    def mock_time(current_time = Time.now)
        @current_time = Time.now
        flexmock(Time).should_receive(:now).and_return { @current_time }
        @current_time
    end

    def mock_time_advance(delta_t)
        @current_time += delta_t
    end
end

describe Utilrb::EventLoop do
    include TimeHelpers

    # Use in the #with clause of a flexmock specification to test whether the
    # argument is the main thread
    def in_main_thread
        Thread.current
    end

    # Use in the #with clause of a flexmock specification to test whether the
    # argument is not the main thread
    def not_in_main_thread
        on { |t| t != @main_thread }
    end

    attr_reader :event_loop
    attr_reader :recorder
    before do
        @event_loop = Utilrb::EventLoop.new
        @recorder = flexmock
        @main_thread = Thread.current
    end

    describe "#every" do
        describe "the queue argument" do
            describe "it is true" do
                it "queues the block right away" do
                    recorder.should_receive(:called).once
                    event_loop.every 0.1, queue: true do
                        recorder.called
                    end
                    event_loop.step
                end
                it "calls the block at the specified period" do
                    current_time = mock_time
                    recorder.should_receive(:called).with(current_time).once
                    event_loop.every 10, queue: true do
                        recorder.called(Time.now)
                    end
                    event_loop.step
                    mock_time_advance(5)
                    event_loop.step
                    current_time = mock_time_advance(6)
                    recorder.should_receive(:called).with(current_time).once
                    event_loop.step
                end
            end
            describe "it is false" do
                it "will not queue the block right away" do
                    recorder.should_receive(:called).never
                    event_loop.every 0.1, queue: false do
                        recorder.called
                    end
                    event_loop.step
                end
                it "calls the block at the specified period" do
                    current_time = mock_time
                    recorder.should_receive(:called).with(current_time).never
                    event_loop.every 10, queue: false do
                        recorder.called(Time.now)
                    end
                    event_loop.step
                    mock_time_advance(5)
                    event_loop.step
                    current_time = mock_time_advance(6)
                    recorder.should_receive(:called).with(current_time).once
                    event_loop.step
                end
            end
        end

        it "starts the timer if start is true" do
            flexmock(Utilrb::EventLoop::Timer).new_instances.
                should_receive(:start).once
            event_loop.every 0.1, start: true do
            end
        end
        it "does not call start if start is false" do
            flexmock(Utilrb::EventLoop::Timer).new_instances.
                should_receive(:start).never
            event_loop.every 0.1, start: false do
            end
        end
    end

    describe "#step" do
        it "calls the timers once their period has expired" do
            vals = Array.new
            event_loop.every(1) { vals[0] = Time.now }
            event_loop.every(2) { vals[1] = Time.now }
            event_loop.every(3) { vals[2] = Time.now }

            expected_vals = Array.new
            expected_vals[0] = expected_vals[1] = expected_vals[2] = mock_time

            event_loop.step
            assert_equal expected_vals, vals
            mock_time_advance(0.5)
            event_loop.steps
            assert_equal expected_vals, vals
            expected_vals[0] = mock_time_advance(0.51)
            event_loop.steps
            assert_equal expected_vals, vals
            mock_time_advance(0.51)
            event_loop.steps
            assert_equal expected_vals, vals
            expected_vals[0] = expected_vals[1] = mock_time_advance(0.51)
            event_loop.steps
            assert_equal expected_vals, vals
            expected_vals[0] = expected_vals[2] = mock_time_advance(1.01)
            event_loop.steps
            assert_equal expected_vals, vals
        end

        it 'calls blocks added with #every_step at each call' do
            recorder.should_receive(:called).with(0).once.ordered
            recorder.should_receive(:called).with(1).once.ordered
            recorder.should_receive(:called).with(2).once.ordered

            i = nil
            event_loop.every_step do
                recorder.called(i)
            end
            i = 0; event_loop.step
            i = 1; event_loop.step
            i = 2; event_loop.step
        end

        it 're-raises an unhandled error from a synchronous call' do
            exception = Class.new(Exception)
            event_loop.once { raise exception }
            assert_raises(exception) { event_loop.step }
        end
        it 're-raises an unhandled error from an asynchronous call' do
            exception = Class.new(Exception)
            event_loop.defer { raise exception }
            event_loop.process_all_async_work
            assert_raises(exception) { event_loop.step }
        end
        it 'queues multiple exceptions to be re-raised in sequence' do
            exception0 = Class.new(Exception)
            event_loop.once { raise exception0 }
            exception1 = Class.new(Exception)
            event_loop.once { raise exception1 }
            assert_raises(exception0) { event_loop.step }
            assert_raises(exception1) { event_loop.step }
            event_loop.step
        end
    end

    describe "#process_timers" do
        it "does not execute the same timer twice" do
            # This is truly a corner-case ... We basically want
            # process_timers(time) to be idempotent for timers with zero period
            recorder.should_receive(:called).once
            event_loop.every 0 do
                recorder.called
            end
            time = Time.now
            event_loop.process_timers(time)
            event_loop.process_timers(time)
        end
    end

    describe "#defer" do
        it "defers blocking calls to a thread pool" do
            recorder = flexmock
            recorder.should_receive(:called).
                with(42, 43, not_in_main_thread).
                once
            event_loop.defer(Hash.new, 42, 43) do |*args|
                recorder.called(*args, Thread.current)
            end
            event_loop.process_all_async_work
        end

        describe "the callback" do
            it "is called within the main thread" do
                recorder.should_receive(:called).with(in_main_thread)
                callback = proc do |_|
                    recorder.called(Thread.current)
                end
                event_loop.defer callback: callback do
                end
                event_loop.process_all_async_work
            end
            it "is passed the work's return value" do
                recorder.should_receive(:called).with([42, 43], nil)
                callback = proc do |result, error|
                    recorder.called(result, error)
                end
                event_loop.defer callback: callback do
                    [42, 43]
                end
                event_loop.process_all_async_work
            end
            it 'can override an error' do
                work_exception = Class.new(Exception)
                callback_exception = Class.new(Exception)
                callback = proc do |r, e|
                    if e
                        callback_exception.new
                    end
                end
                event_loop.defer callback: callback do
                    raise work_exception
                end
                event_loop.process_all_async_work
                assert_raises callback_exception do
                    event_loop.step
                end
            end
            it 'can ignore an error' do
                work = Proc.new do
                    raise ArgumentError
                end
                event_loop.async work do |r,e|
                    if e
                        :ignore_error
                    end
                end
                event_loop.process_all_pending_work
            end
        end
    end

    describe "#async_every" do
        it "periodically defers the execution of its block to a thread pool" do
            work_block = proc do
                [Time.now, Thread.current]
            end

            current_time = mock_time
            event_loop.async_every(work_block, queue: true, period: 0.1) do |result,e|
                recorder.called(*result)
            end

            recorder.should_receive(:called).with(current_time, not_in_main_thread).
                ordered
            event_loop.process_all_async_work
            event_loop.step

            mock_time_advance(0.05)
            event_loop.process_all_async_work
            event_loop.step

            current_time = mock_time_advance(0.06)
            recorder.should_receive(:called).with(current_time, not_in_main_thread).
                ordered
            event_loop.process_all_async_work
            event_loop.step
        end
        it "queues the block right away if queue is true" do
            recorder.should_receive(:called).once
            event_loop.async_every(lambda {}, queue: true, period: 20) do |result,e|
                recorder.called(*result)
            end
            event_loop.process_all_async_work
            event_loop.step
        end
        it "does not queue the block right away if queue is false" do
            recorder.should_receive(:called).never
            event_loop.async_every(lambda {}, queue: false, period: 20) do |result,e|
                recorder.called(*result)
            end
            event_loop.process_all_async_work
            event_loop.step
        end
    end

    describe "#once" do
        it "queues work to be executed in the next call to step" do
            event_loop.once { recorder.called }
        end

        describe "with a delay" do
            it "queues the work to be executed exactly once after delay seconds" do
                current_time = mock_time
                recorder.should_receive(:called).never.with(current_time)
                event_loop.once(1) { recorder.called(Time.now) }
                event_loop.step
                current_time = mock_time_advance(2)
                recorder.should_receive(:called).once.with(current_time)
                event_loop.step
            end
        end
    end

    describe "#on_error" do
        attr_reader :exception_t
        attr_reader :filter
        attr_reader :recorder
        before do
            @exception_t = Class.new(Exception)
            @filter = flexmock
            @recorder = flexmock
            event_loop.on_error filter do |e|
                recorder.called(e)
            end
        end

        it "registers the block to be called with exceptions matching the filter" do
            filter.should_receive(:===).with(exception_t).and_return(true)
            recorder.should_receive(:called).with(exception_t).once
            event_loop.once { raise exception_t }
            assert_raises(exception_t) { event_loop.step }
        end
        it "ignores exceptions that do not match the filter" do
            filter.should_receive(:===).with(exception_t).and_return(false)
            recorder.should_receive(:called).never
            event_loop.once { raise exception_t }
            assert_raises(exception_t) { event_loop.step }
        end
    end

    describe "#exec" do
        it "steps at the required period" do
            flexmock(Kernel).should_receive(:sleep)
            event_loop = Utilrb::EventLoop.new
            event_loop.once 0.2 do
                event_loop.stop
            end
            event_loop.exec
        end

        it 'must raise if step is called from a wrong thread' do
            event_loop.defer do
                event_loop.step
            end
            event_loop.process_all_async_work
            assert_raises RuntimeError do
                event_loop.step
            end
        end
    end

    describe "#call" do
        describe "when called outside the event thread" do
            it 'queues the block in the event queue' do
                recorder.should_receive(:called).with(0, not_in_main_thread).
                    once.ordered
                recorder.should_receive(:called).with(1, in_main_thread).
                    once.ordered
                event_loop.defer do
                    recorder.called(0, Thread.current)
                    event_loop.call do
                        recorder.called(1, Thread.current)
                        assert event_loop.thread?
                    end
                end
                event_loop.process_all_async_work
                event_loop.step
            end
        end
        describe "when called from the event thread" do
            it "calls the block right away" do
                recorder.should_receive(:called).with(in_main_thread).
                    once
                event_loop.call do
                    recorder.called(Thread.current)
                end
                event_loop.step
            end
        end
    end

    describe Utilrb::EventLoop::Forwardable do
        attr_reader :proxy_class
        before do
            @proxy_class = Class.new do
                attr_accessor :obj
                extend Utilrb::EventLoop::Forwardable
                def initialize(event_loop, obj)
                    @event_loop = event_loop
                    @obj = obj
                end
                def_event_loop_delegator :@obj,:@event_loop,:call
            end
        end
        let(:event_loop) { Utilrb::EventLoop.new }
        let(:obj) { flexmock }
        let(:proxy) { proxy_class.new(event_loop, obj) }

        describe "the designated object is nil" do
            it "raises DesignatedObjectNotFound on synchronous method call" do
                proxy = proxy_class.new(event_loop, nil)
                assert_raises Utilrb::EventLoop::Forwardable::DesignatedObjectNotFound do
                    proxy.call
                end
            end

            it "raises DesignatedObjectNotFound right away on asynchronous method call" do
                proxy = proxy_class.new(event_loop, nil)
                assert_raises Utilrb::EventLoop::Forwardable::DesignatedObjectNotFound do
                    proxy.call do |*_|
                    end
                end
            end

            it "raises DesignatedObjectNotFound when processing on asynchronous method call" do
                obj.should_receive(:call)
                event_loop.thread_pool.disable_processing
                proxy.call do |*_|
                end
                proxy.obj = nil
                event_loop.thread_pool.enable_processing
                event_loop.process_all_async_work

                assert_raises Utilrb::EventLoop::Forwardable::DesignatedObjectNotFound do
                    event_loop.step
                end
            end
        end

        describe "calling a method without a block" do
            it "calls the method synchronously on the real object and returns the returned value" do
                obj.should_receive(:call).and_return { Thread.current }
                assert_equal Thread.current, proxy.call
            end

            it "passes arguments to the method" do
                obj.should_receive(:call).with(*(args = [flexmock, flexmock])).
                    and_return { args }
                assert_equal args, proxy.call(*args)
            end

            it "forwards any exception raised by the called method" do
                exception = Class.new(Exception)
                obj.should_receive(:call).and_raise(exception)
                assert_raises(exception) do
                    proxy.call
                end
            end

            it 'calls the error callback from within the event loop if the method raises an exception' do
                exception = Class.new(Exception)
                obj.should_receive(:call).and_raise(exception)

                recorder.should_receive(:called).with(exception, in_main_thread).once
                proxy.call do |_,e|
                    recorder.called(e, Thread.current)
                    :ignore_error
                end
                event_loop.process_all_async_work
                event_loop.step
            end

            it 'allows calling the proxy instance methods' do
                flexmock(proxy).should_receive(:call).once
                proxy.call
            end
        end

        describe "calling a method with a block" do
            it "defers the method call to a thread pool and uses the block as callback" do
                obj.should_receive(:call).
                    with(arg0 = flexmock, arg1 = flexmock).
                    and_return(ret = flexmock)

                recorder = flexmock
                recorder.should_receive(:called).
                    with(ret, in_main_thread).
                    once
                task = proxy.call(arg0, arg1) do |result|
                    recorder.called(result, Thread.current)
                end
                task.wait
                event_loop.step
            end
        end
    end

    describe Utilrb::EventLoop::Timer do
        describe "#cancel" do
            it "stops a running timer" do
                recorder.should_receive(:called).never
                timer0 = event_loop.every 0.1 do
                    recorder.called
                end
                timer0.cancel
                event_loop.step
            end
        end
        describe "#start" do
            it "reenables a cancelled timer" do
                recorder.should_receive(:called).once
                timer = event_loop.every 0.1 do
                    recorder.called
                end
                timer.cancel
                event_loop.step
                timer.start
                event_loop.step
            end
        end
    end

    describe Utilrb::EventLoop::AsyncTimer do
        describe "#on_completion" do
            it "register completion blocks that are executed once the next time the work finished" do
                recorder.should_receive(:called).with(in_main_thread).once
                work = proc { }
                timer = event_loop.async_every work, period: 0.1 do |_|
                end
                timer.on_completion { recorder.called(Thread.current) }
                event_loop.process_all_async_work
                event_loop.step
            end
        end
        describe "#execute" do
            it "allows for immediate synchronous execution of the timer's work" do
                recorder.should_receive(:called).with(in_main_thread).once.
                    and_return(ret = flexmock)
                work = lambda { recorder.called(Thread.current) }
                timer = event_loop.async_every work, period: 0.1 do |_|
                end
                assert_equal ret, timer.execute
            end

            it "re-raises an exception raised by the work block" do
                exception = Class.new(Exception)
                recorder = flexmock
                recorder.should_receive(:called).with(in_main_thread).once.
                    and_raise(exception)
                work = lambda { recorder.called(Thread.current) }
                timer = event_loop.async_every work, period: 0.1 do |_|
                end
                assert_raises(exception) { timer.execute }
            end

            it "calls the completion blocks" do
                recorder.should_receive(:called).with(in_main_thread).once
                work = lambda {}
                timer = event_loop.async_every work, period: 0.1 do |_|
                end
                timer.on_completion { recorder.called(Thread.current) }
                timer.execute
            end
        end
    end
end

