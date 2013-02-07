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
            assert_equal 20,pool.backlog
            assert_equal 20,pool.tasks.size
            sleep 0.1
            assert_equal 0,pool.backlog
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
                    sleep 0.15
                end
            end
            sleep 0.13
            assert_equal 0,pool.waiting
            assert_equal 20,pool.spawned
            sleep 0.4
            assert_equal 5,pool.waiting
            assert_equal 5,pool.spawned
            pool.shutdown
            pool.join
        end

        it "must not execute tasks with the same sync key in parallel" do
            pool = Utilrb::ThreadPool.new(5,10)
            pool.auto_trim = true
            time = Time.now
            0.upto 10 do 
                t = pool.process_with_options :sync_key => time do
                    sleep 0.1
                end
                assert_equal time, t.sync_key
            end
            while pool.backlog > 0
                sleep 0.1
            end
            pool.shutdown
            pool.join
            assert Time.now - time >= 1.0
        end

        it "must not execute a task and a sync call in parallel if they have the same sync key" do
            pool = Utilrb::ThreadPool.new(5,5)
            time = Time.now
            t = pool.process_with_options :sync_key => 1 do
                sleep 0.2
            end
            pool.sync 1 do 
                sleep 0.2
            end
            while pool.backlog > 0
                sleep 0.1
            end
            pool.shutdown
            pool.join
            assert Time.now - time >= 0.4
        end

        it "must execute a task and a sync call in parallel if they have different sync keys" do
            pool = Utilrb::ThreadPool.new(5,5)
            time = Time.now
            t = pool.process_with_options :sync_key => 1 do
                sleep 0.2
            end
            pool.sync 2 do 
                sleep 0.2
            end
            while pool.backlog > 0
                sleep 0.1
            end
            pool.shutdown
            pool.join
            assert Time.now - time < 0.4
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

        it "must be able to reque a task" do 
            pool = Utilrb::ThreadPool.new(5)
            count = 0
            task = pool.process do 
                count += 1
            end
            while !task.finished?
                sleep 0.001
            end
            pool << task 
            while !task.finished?
                sleep 0.001
            end
            assert_equal 2, count
        end

        it "must process the next task if thread gets available" do 
            pool = Utilrb::ThreadPool.new(1)
            count = 0
            pool.process do 
                sleep 0.1
                count +=1
            end
            pool.process do 
                sleep 0.1
                count +=1
            end
            sleep 0.25
            assert_equal 2, count

            task3 = Utilrb::ThreadPool::Task.new do
                count +=1
                sleep 0.1
            end
            task4 = Utilrb::ThreadPool::Task.new do
                count +=1
                sleep 0.1
            end
            pool << task3
            pool << task4
            sleep 0.15
            pool.shutdown
            pool.join
            assert_equal 4, count
        end
    end

    describe "when shutting down" do
        it "must terminate all threads" do 
            pool = Utilrb::ThreadPool.new(5)
            task = pool.process do 
                sleep 0.2
            end
            pool.shutdown()
            pool.join
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
            assert !task.terminated?
            assert !task.successfull?
            assert !task.started?
            assert_equal :waiting, task.state
        end
        it "must raise if wrong option is given." do 
            assert_raises ArgumentError do 
                task = Utilrb::ThreadPool::Task.new :bla => 123 do 
                end
            end
        end
        it "must set its options." do
            task = Utilrb::ThreadPool::Task.new :sync_key => 2 do 
                123
            end
            assert_equal 2,task.sync_key
        end
    end

    describe "when executed" do
        it "must be in finished state if task successfully executed." do
            task = Utilrb::ThreadPool::Task.new do 
                123
            end
            task.pre_execute
            task.execute
            task.finalize
            assert !task.running?
            assert task.finished?
            assert !task.exception?
            assert !task.terminated?
            assert task.successfull?
            assert task.started?
        end

        it "must call the callback after it is finished." do 
            task = Utilrb::ThreadPool::Task.new do 
                123
            end
            result = nil
            task.callback do |val,e|
                result = val
            end
            task.pre_execute
            task.execute
            task.finalize

            assert_equal 123,result
            assert !task.running?
            assert task.finished?
            assert !task.exception?
            assert !task.terminated?
            assert task.successfull?
            assert task.started?
        end

        it "must be in exception state if exception was raised." do 
            task = Utilrb::ThreadPool::Task.new do 
                raise
            end
            task.pre_execute
            task.execute
            task.finalize
            assert !task.running?
            assert task.finished?
            assert task.exception?
            assert !task.terminated?
            assert !task.successfull?
            assert task.started?

            task = Utilrb::ThreadPool::Task.new do 
                raise
            end
            result = nil
            task.callback do |val,e|
                result = val ? val : e
            end
            task.pre_execute
            task.execute
            task.finalize
            assert !task.running?
            assert task.finished?
            assert task.exception?
            assert !task.terminated?
            assert !task.successfull?
            assert task.started?
            assert_equal RuntimeError, result.class
        end

        it "must return the default value if an error was raised." do 
            task = Utilrb::ThreadPool::Task.new :default => 123 do 
                raise
            end
            result = nil
            task.callback do |val,e|
                result = val
            end
            task.pre_execute
            task.execute
            task.finalize
            assert !task.running?
            assert task.finished?
            assert task.exception?
            assert !task.terminated?
            assert !task.successfull?
            assert task.started?
            assert_equal 123,result
        end

        it "must calculate its elapsed time." do 
            task = Utilrb::ThreadPool::Task.new do 
                sleep 0.2
            end
            assert_in_delta 0.0,task.time_elapsed,0.0001
            thread = Thread.new do 
                task.pre_execute
                task.execute
                task.finalize
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
                task.pre_execute
                task.execute
                task.finalize
            end
            sleep 0.1
            task.terminate!
            thread.join

            assert !task.running?
            assert task.finished?
            assert !task.exception?
            assert task.terminated?
            assert !task.successfull?
            assert task.started?
        end
    end

    describe "when terminated" do
        it "must be in state terminated." do 
            task = Utilrb::ThreadPool::Task.new do 
                sleep 10
            end
            thread = Thread.new do
                task.pre_execute
                task.execute
                task.finalize
            end
            sleep 0.1
            task.terminate!()
            thread.join

            assert !task.running?
            assert task.finished?
            assert !task.exception?
            assert task.terminated?
            assert !task.successfull?
            assert task.started?
        end
    end
end

