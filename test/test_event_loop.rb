require './test_config'
require 'utilrb/event_loop'
require 'minitest/spec'

MiniTest::Unit.autorun

describe Utilrb::EventLoop::Forwardable do
    class Dummy
        def test(wait)
            sleep wait
            Thread.current
        end

        def error
            raise
        end
    end

    class DummyAsync
        extend Utilrb::EventLoop::Forwardable
        def_event_loop_delegator :@obj,:@event_loop,:test,:alias => :atest
        def_event_loop_delegators :@obj,:@event_loop,[:bla1,:bla2]
        def_event_loop_delegator :@obj,:@event_loop,:error,:on_error => :on_error2,:known_errors => RuntimeError

        forward_to :@obj, :@event_loop do
            thread_safe do 
                def_delegators :bla3,:bla4
            end
            def_delegators :bla5
        end

        attr_accessor :last_error

        def initialize(event_loop,obj = Dummy.new)
            @event_loop = event_loop
            @obj = obj
        end

        def on_error2(error)
            @last_error = error
        end

    end

    class DummyAsyncFilter
        extend Utilrb::EventLoop::Forwardable

        def do_not_overwrite
            222
        end

        def_event_loop_delegator :@obj,:@event_loop,:test,:alias => :atest2
        def_event_loop_delegator :@obj,:@event_loop,:test,:alias => :atest,:filter => :test_filter
        def_event_loop_delegator :@obj,:@event_loop,:test,:alias => :do_not_overwrite
        
        def initialize(event_loop,obj = Dummy.new)
            @event_loop = event_loop
            @obj = obj
        end

        # the result is always returned as array to check 
        # that the filer is working
        def test_filter(result)
            [result,result]
        end
    end

    describe "when a class is extend but the designated object is nil" do
        it "must raise if a method call is delegated." do
            event_loop = Utilrb::EventLoop.new
            obj = DummyAsync.new(event_loop,nil)
            assert_raises Utilrb::EventLoop::Forwardable::DesignatedObjectNotFound do 
                obj.atest(0.1)
            end
            assert_raises Utilrb::EventLoop::Forwardable::DesignatedObjectNotFound do 
                obj.atest(0.1) do |_|
                end
                sleep 0.1
                event_loop.step
            end
        end

        it "must raise if a method call is delegated but the underlying object is nil." do
            event_loop = Utilrb::EventLoop.new
            obj = DummyAsyncFilter.new(event_loop,nil)
            assert_raises Utilrb::EventLoop::Forwardable::DesignatedObjectNotFound do 
                obj.atest(0.1)
            end
        end
    end

    describe "when a class is extend" do
        it "must delegate the method call directly to the real object." do
            event_loop = Utilrb::EventLoop.new
            obj = DummyAsyncFilter.new(event_loop)
            assert_equal Thread.current,obj.atest(0.1).first
        end

        it 'must call the error callback' do 
            event_loop = Utilrb::EventLoop.new
            obj = DummyAsync.new(event_loop)
            assert_raises RuntimeError do 
                obj.error
            end
            obj.last_error.must_be_instance_of RuntimeError
            obj.last_error = nil
            error = nil
            obj.error do |_,e|
                error = e
            end
            sleep 0.1
            event_loop.step
            error.must_be_instance_of RuntimeError
            obj.last_error.must_be_instance_of RuntimeError
        end

        it 'must not overwrite instance methods' do 
            event_loop = Utilrb::EventLoop.new
            obj = DummyAsyncFilter.new(event_loop)
            assert_equal 222,obj.do_not_overwrite
        end

        it "must defer the method call to a thread pool if a block is given." do
            event_loop = Utilrb::EventLoop.new
            obj = DummyAsync.new(event_loop)
            thread = nil
            task = obj.atest(0.05) do |result|
                thread = result
            end
            assert_equal Utilrb::ThreadPool::Task,task.class
            sleep 0.1
            event_loop.step
            assert task.successfull?
            assert thread != Thread.current
        end
    end
end

describe Utilrb::EventLoop do
    describe "when executed" do
        it "must call the timers at the right point in time." do
            event_loop = Utilrb::EventLoop.new
            val1 = nil
            val2 = nil
            val3 = nil
            timer1 = event_loop.every 0.1 do 
                val1 = 123
            end
            timer2 = event_loop.every 0.2 do 
                val2 = 345
            end
            event_loop.once 0.3 do 
                val3 = 444
            end

            time = Time.now
            while Time.now - time < 0.101
                event_loop.step
            end
            event_loop.steps
            assert_equal 123,val1
            assert_equal nil,val2
            assert_equal nil,val3
            val1 = nil

            time = Time.now
            while Time.now - time < 0.101
                event_loop.step
            end
            assert_equal 123,val1
            assert_equal 345,val2
            assert_equal nil,val3

            time = Time.now
            while Time.now - time < 0.101
                event_loop.step
            end
            assert_equal 444,val3
            event_loop.clear
        end

        it 'must call a given block for every step' do 
            event_loop = Utilrb::EventLoop.new
            val = nil
            event_loop.every_step do 
                val = 123
            end
            event_loop.step
            assert_equal 123,val
            val = nil
            event_loop.step
            assert_equal 123,val
            val = nil
            event_loop.step
            assert_equal 123,val
        end

        it "must be able to start and stop timers." do
            event_loop = Utilrb::EventLoop.new
            val1 = nil
            val2 = nil
            timer1 = event_loop.every 0.1 do 
                val1 = 123
            end
            assert timer1.running?
            timer2 = event_loop.every 0.2 do 
                val2 = 345
            end
            assert timer2.running?

            timer1.cancel
            assert !timer1.running?
            time = Time.now
            event_loop.wait_for do 
                Time.now - time >= 0.22
            end
            assert_equal nil,val1
            assert_equal 345,val2
            val2 = nil
            timer1.start
            timer2.cancel

            time = Time.now
            while Time.now - time < 0.201
                event_loop.step
            end
            assert_equal 123,val1
            assert_equal nil,val2
        end

        it "must defer blocking calls to a thread pool" do 
            event_loop = Utilrb::EventLoop.new
            main_thread = Thread.current
            val = nil
            val2 = nil
            callback = Proc.new do |result| 
                assert_equal main_thread,Thread.current
                assert main_thread != result
                val = result
            end
            event_loop.defer({:callback => callback},123,333) do |a,b|
                assert_equal 123,a
                assert_equal 333,b
                sleep 0.2
                assert main_thread != Thread.current
                val2 = Thread.current
            end
            sleep 0.1
            event_loop.step
            assert !val

            sleep 0.11
            event_loop.step
            assert val
            assert_equal val,val2
        end
        it "must peridically defer blocking calls to a thread pool" do 
            event_loop = Utilrb::EventLoop.new
            main_thread = Thread.current
            work = Proc.new do 
                Thread.current
            end
            val = nil
            event_loop.async_every work,:period => 0.1 do |result,e|
                val = result
            end
            sleep 0.11
            event_loop.step
            assert !val
            sleep 0.01
            event_loop.step
            assert val
            assert val != main_thread
            val = nil

            sleep 0.11
            event_loop.step
            sleep 0.01
            event_loop.step
            assert val
            assert val != main_thread
        end

        it 'must be able to overwrite an error' do 
            event_loop = Utilrb::EventLoop.new
            work = Proc.new do 
                raise ArgumentError
            end
            event_loop.async work do |r,e|
                if e
                    RuntimeError.new
                end
            end
            sleep 0.1
            assert_raises RuntimeError do
                event_loop.step
            end
        end

        it 'must be able to ignore an error' do 
            event_loop = Utilrb::EventLoop.new
            work = Proc.new do 
                raise ArgumentError
            end
            event_loop.async work do |r,e|
                if e
                    :ignore_error
                end
            end
            sleep 0.1
            event_loop.step
        end

        it 'must inform on_error block in an event of an error' do 
            event_loop = Utilrb::EventLoop.new
            error = nil
            event_loop.on_error ArgumentError do |e|
                error = e
            end

            #check super class 
            error2 = nil
            event_loop.on_error Exception do |e|
                error2 = e
            end
            work = Proc.new do
                raise ArgumentError
            end
            event_loop.async_with_options work, :default => :default_value,:known_errors => ArgumentError do |r,e|
            end
            sleep 0.1
            event_loop.step
            assert error
            assert error2
        end

        it 'must re-raise an error' do 
            event_loop = Utilrb::EventLoop.new
            event_loop.once do
                raise ArgumentError
            end
            event_loop.once do
                raise ArgumentError
            end
            event_loop.once do
                raise ArgumentError
            end
            assert_raises ArgumentError do 
                event_loop.step
            end
            assert_raises ArgumentError do 
                event_loop.step
            end
            event_loop.clear_errors
            event_loop.step

            event_loop.defer Hash.new, 123,22,333 do |a,b,c|
                assert_equal 123,a
                assert_equal 22,b
                assert_equal 333,c
                raise ArgumentError
            end
            sleep 0.1
            assert_raises ArgumentError do 
                event_loop.step
            end
        end

        it 'must automatically step' do
            event_loop = Utilrb::EventLoop.new
            event_loop.once 0.2 do
                event_loop.stop
            end
            event_loop.exec
        end

        it 'must raise if step is called from a wrong thread' do 
            event_loop = Utilrb::EventLoop.new
            event_loop.defer do
                event_loop.step
            end
            sleep 0.1
            assert_raises RuntimeError do 
                event_loop.step
            end
        end

        it 'must call a given block from the event loop thread' do 
            event_loop = Utilrb::EventLoop.new
            event_loop.thread = Thread.current
            result1,result2 = [nil,nil]
            event_loop.defer do
                result1 = Thread.current
                event_loop.call do
                    result2 = Thread.current
                    assert event_loop.thread?
                end
            end
            sleep 0.1
            event_loop.step
            assert result1
            assert result1 != result2
            assert_equal Thread.current,result2
        end
    end
end

