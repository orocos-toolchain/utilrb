require './test_config'
require 'utilrb/thread_pool'
require 'minitest/spec'

MiniTest::Unit.autorun

describe Utilrb::ThreadPool do
    describe "when created" do
        it "must create min number of threads." do 
            pool = Utilrb::ThreadPool.new(5)
            sleep 0.1
            assert_equal 5,pool.waiting
            assert_equal 5,pool.spawned
            assert_equal 5,(pool.instance_variable_get(:@workers)).size
            pool.shutdown
            pool.join
        end

        it "must create min number of threads." do 
            pool = Utilrb::ThreadPool.new(5)
            sleep 0.1
            assert_equal 5,pool.waiting
            assert_equal 5,pool.spawned
            assert_equal 5,(pool.instance_variable_get(:@workers)).size
            pool.shutdown
            pool.join
        end
    end

    describe "when under heavy load" do
        it "must spawn upto max threads." do 
            pool = Utilrb::ThreadPool.new(5,20)
            0.upto 19 do 
                pool.process do 
                    sleep 0.12
                end
            end
            sleep 0.1
            assert_equal 0,pool.waiting
            assert_equal 20,pool.spawned
            sleep 0.1
            assert_equal 20,pool.waiting
            assert_equal 20,pool.spawned
            pool.shutdown
            pool.join
        end

        it "must be possible to resize its limit" do 
            pool = Utilrb::ThreadPool.new(5,5)
            0.upto 19 do 
                pool.process do 
                    sleep 0.32
                end
            end
            sleep 0.1
            assert_equal 0,pool.waiting
            assert_equal 5,pool.spawned
            pool.resize(5,20)
            sleep 0.1
            assert_equal 0,pool.waiting
            assert_equal 20,pool.spawned
            sleep 0.4
            assert_equal 20,pool.spawned
            assert_equal 20,pool.waiting
            pool.shutdown
            pool.join
        end

        it "must reduce its number of threads after the work is done if auto_trim == true." do 
            pool = Utilrb::ThreadPool.new(5,20)
            pool.auto_trim = true
            0.upto 19 do 
                pool.process do 
                    sleep 0.12
                end
            end
            sleep 0.1
            assert_equal 0,pool.waiting
            assert_equal 20,pool.spawned
            sleep 0.4
            assert_equal 5,pool.waiting
            assert_equal 5,pool.spawned
            pool.shutdown
            pool.join
        end
    end

    describe "when running" do
        it "must call on_task_finished for each finised task." do 
            pool = Utilrb::ThreadPool.new(5)
            count = 0
            pool.on_task_finished do |task|
                count += 1
            end
            task = pool.process do 
                sleep 0.05
            end
            task = pool.process do 
                raise
            end
            sleep 0.1
            assert_equal 2,count
            pool.shutdown
            pool.join
        end
    end

    describe "when watchdog is running" do
        it "must timeout tasks taking too long." do 
            pool = Utilrb::ThreadPool.new(5)
            pool.watchdog
            task = pool.process do 
                sleep 10
            end
            task.timeout = 0.1
            sleep 0.12
            assert !task.running?
            assert task.timeout?
            pool.shutdown
            pool.join
        end
    end

    describe "when shutting down" do
        it "must terminate tasks taking too long." do 
            pool = Utilrb::ThreadPool.new(5)
            task = pool.process do 
                sleep 3
            end
            sleep 0.1
            pool.shutdown(0.3)
            pool.join
            assert task.timeout?
        end
    end
end


describe Utilrb::ThreadPool::Task do
    describe "when created" do
        it "must raise if no block is given." do 
            assert_raises(ArgumentError) do
                Utilrb::ThreadPool::Task.new
            end
        end
        it "must be in waiting state." do 
            task = Utilrb::ThreadPool::Task.new do 
            end
            assert !task.running?
            assert !task.finished?
            assert !task.exception?
            assert !task.timeout?
            assert !task.terminated?
            assert !task.successfull?
            assert !task.started?
            assert_equal :waiting, task.state
        end
    end

    describe "when executed" do
        it "must be in finished state if task successfully executed." do 
            task = Utilrb::ThreadPool::Task.new do 
            end
            task.execute
            assert !task.running?
            assert task.finished?
            assert !task.exception?
            assert !task.timeout?
            assert !task.terminated?
            assert task.successfull?
            assert task.started?
        end

        it "must be in exception state if exception was raised." do 
            task = Utilrb::ThreadPool::Task.new do 
                raise
            end
            task.execute
            assert !task.running?
            assert task.finished?
            assert task.exception?
            assert !task.timeout?
            assert !task.terminated?
            assert !task.successfull?
            assert task.started?
        end

        it "must calculate its elapsed time." do 
            task = Utilrb::ThreadPool::Task.new do 
                sleep 0.2
            end
            assert_in_delta 0.0,task.time_elapsed,0.0001
            thread = Thread.new do 
                task.execute
            end
            sleep 0.1
            assert_in_delta 0.1,task.time_elapsed,0.01
            thread.join
            assert_in_delta 0.2,task.time_elapsed,0.001
            sleep 0.1
            assert_in_delta 0.2,task.time_elapsed,0.001
        end
    end

    describe "when terminated" do
        it "it must be in terminated state." do 
            task = Utilrb::ThreadPool::Task.new do 
                sleep 10
            end
            thread = Thread.new do
                task.execute
            end
            sleep 0.1
            task.terminate!
            thread.join

            assert !task.running?
            assert task.finished?
            assert !task.exception?
            assert !task.timeout?
            assert task.terminated?
            assert !task.successfull?
            assert task.started?
        end
    end

    describe "when timeout" do
        it "must be in timeout state." do 
            task = Utilrb::ThreadPool::Task.new do 
                sleep 10
            end
            thread = Thread.new do
                task.execute
            end
            sleep 0.1
            task.terminate!(Utilrb::ThreadPool::Task::Timeout)
            thread.join

            assert !task.running?
            assert task.finished?
            assert !task.exception?
            assert task.timeout?
            assert !task.terminated?
            assert !task.successfull?
            assert task.started?
        end
    end
end

