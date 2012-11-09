require './test_config'
require 'utilrb/event_loop'
require 'minitest/spec'

MiniTest::Unit.autorun

describe Utilrb::EventLoop do
    describe "when executed" do
        it "must call the timers at the right point in time." do
            event_loop = Utilrb::EventLoop.new
            val1 = nil
            val2 = nil
            val3 = nil
            val4 = nil
            timer1 = event_loop.every 0.1 do 
                val1 = 123
            end
            timer2 = event_loop.every 0.2 do 
                val2 = 345
            end
            event_loop << Proc.new do
                val3 = 222
            end
            event_loop.once 0.3 do 
                val4 = 444
            end

            time = Time.now
            while Time.now - time < 0.101
                event_loop.step
            end
            assert_equal 123,val1
            assert_equal nil,val2
            assert_equal 222,val3
            assert_equal nil,val4
            val1 = nil
            val3 = nil

            time = Time.now
            while Time.now - time < 0.101
                event_loop.step
            end
            assert_equal 123,val1
            assert_equal 345,val2
            assert_equal nil,val3
            assert_equal nil,val4

            time = Time.now
            while Time.now - time < 0.101
                event_loop.step
            end
            assert_equal nil,val3
            assert_equal 444,val4
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
            while Time.now - time < 0.201
                event_loop.step
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
            event_loop.defer callback,123,333 do |a,b|
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

        it 'must handle errors if a handler is registered' do 
            event_loop = Utilrb::EventLoop.new
            val = nil
            val2 = nil

            error_handler = Proc.new do |error| 
                if(error.class == Exception)
                    val = error
                    true
                end
            end
            event_loop.defer nil, error_handler do
                raise Exception
            end

            sleep 0.1
            event_loop.step
            assert_equal Exception, val.class
            assert_equal nil, val2

            val = nil
            event_loop.error_handler do |error|
                if error.class == Utilrb::EventLoop::EventLoopError
                    val2 = error.error
                    error.class == Utilrb::EventLoop::EventLoopError
                    true
                end
            end

            event_loop.defer nil, error_handler do
                raise ArgumentError
            end
            sleep 0.1
            event_loop.step
            assert_equal nil, val
            assert_equal ArgumentError, val2.class

            val2 = nil
            event_loop.once do
                raise ArgumentError
            end
            event_loop << Proc.new  do |error|
                val2 = error
                error.class == ArgumentError
            end
            event_loop.step
            assert_equal ArgumentError, val2.class
        end

        it 'must re-raise an error if no handler is registered' do 
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

            event_loop.defer 123,22,333 do |a,b,c|
                assert_equal 123,a
                assert_equal 22,b
                assert_equal 333,c
                raise Exception
            end
            sleep 0.1
            assert_raises Utilrb::EventLoop::EventLoopError do 
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
    end
end

