require 'utilrb/test'
require 'utilrb/thread_pool'
require 'minitest/spec'
require 'flexmock/minitest'

module AsyncWorkHelper
    attr_reader :mutex, :cv, :pool

    def setup
        super
        @mutex = Mutex.new
        @cv = ConditionVariable.new
        @active_synchronized_workers_count = 0
        @spawned_synchronized_workers_count = 0
    end

    def teardown
        while (current = spawned_synchronized_workers_count) > 0
            wait_until do
                release_synchronized_workers
                assert current != spawned_synchronized_workers_count
            end
        end

        if pool
            pool.shutdown
            pool.join
        end
        super
    end

    def active_synchronized_workers_count
        mutex.synchronize { @active_synchronized_workers_count }
    end

    def spawned_synchronized_workers_count
        mutex.synchronize { @spawned_synchronized_workers_count }
    end

    def wait_synchronized_workers(count)
        wait_until do
            assert_equal count, active_synchronized_workers_count
        end
    end

    def wait_until(timeout: 5, &block)
        start = Time.now
        while true
            begin
                block.call
                return
            rescue Minitest::Assertion
                if (Time.now - start > timeout)
                    raise
                end
            end
            Thread.pass
        end
        block.call
    end

    def synchronized_work(already_locked: false)
        if !already_locked
            return mutex.synchronize { synchronized_work(already_locked: true) }
        end

        @active_synchronized_workers_count += 1
        begin
            cv.wait(mutex)
        ensure
            @active_synchronized_workers_count -= 1
        end
    end

    def release_synchronized_workers
        cv.broadcast
    end
end

describe Utilrb::ThreadPool do
    include AsyncWorkHelper

    let(:spy) { flexmock }

    def create_pool(*args)
        if pool
            raise RuntimeError, "pool already created, call #shutdown_pool first"
        end
        @pool = Utilrb::ThreadPool.new(*args)
    end

    def shutdown_pool
        pool.shutdown
        pool.join
    end

    def spawn_synchronized_workers(count, &spawner)
        spawner ||= lambda { |p, &b| p.process(&b) }

        count.times do
            mutex.synchronize do
                @spawned_synchronized_workers_count += 1
            end
            spawner.call(pool) do
                mutex.synchronize do
                    begin
                        synchronized_work(already_locked: true)
                    ensure
                        @spawned_synchronized_workers_count -= 1
                    end
                end
            end
        end
    end

    describe "when created" do
        it "must create min number of threads." do 
            create_pool 5
            wait_until { assert_equal 5, pool.waiting }
            assert_equal 5, pool.waiting
            assert_equal 5, pool.spawned
        end
    end

    describe "when under heavy load" do
        it "must spawn max threads." do 
            create_pool 0, 10
            spawn_synchronized_workers(15)
            wait_synchronized_workers(10)
            assert_equal 0, pool.waiting
            assert_equal 5,pool.backlog
            assert_equal 10,pool.spawned
            release_synchronized_workers
        end

        it "must be possible to resize the max limit" do 
            create_pool 0, 5
            spawn_synchronized_workers(10)
            wait_synchronized_workers(5)
            pool.resize(0, 8)
            wait_synchronized_workers(8)
            assert_equal 2,pool.backlog
            assert_equal 0,pool.waiting
            assert_equal 8,pool.spawned
        end

        it "must reduce its number of threads after the work is done if auto_trim == true." do 
            create_pool 2, 5
            pool.auto_trim = true
            spawn_synchronized_workers(8)
            wait_synchronized_workers(5)
            release_synchronized_workers
            wait_synchronized_workers(3)
            assert_equal 3, pool.spawned
            release_synchronized_workers
            wait_synchronized_workers(0)
            assert_equal 2, pool.spawned
        end

        it "must not execute tasks with the same sync key in parallel" do
            key = Object.new
            create_pool 10
            spawn_synchronized_workers 1000 do |pool, &w|
                w = pool.process_with_options(sync_key: key, &w)
                assert_equal key, w.sync_key
            end
            wait_synchronized_workers(1)
            1000.times do |i|
                wait_until { assert_equal (1000 - i), spawned_synchronized_workers_count }
                wait_synchronized_workers(1)
                release_synchronized_workers
            end
        end

        it "must not execute a task and a sync call in parallel if they have the same sync key" do
            key = Object.new
            create_pool 2
            sync_call_thread = Thread.new do
                pool.sync(key, &method(:synchronized_work))
            end
            wait_synchronized_workers 1
            spawn_synchronized_workers 1 do |pool, &w|
                pool.process_with_options(sync_key: key, &w)
            end
            assert_equal 1, pool.backlog
            release_synchronized_workers
            wait_synchronized_workers 1
        end

        it "must execute a task and a sync call in parallel if they have different sync keys" do
            create_pool 2
            sync_call_thread = Thread.new do
                pool.sync(Object.new, &method(:synchronized_work))
            end
            wait_synchronized_workers 1
            spawn_synchronized_workers 1 do |pool, &w|
                pool.process_with_options(sync_key: Object.new, &w)
            end
            wait_synchronized_workers 2
            release_synchronized_workers
        end
    end

    describe "when running" do
        it "must call on_task_finished for each finised task." do 
            create_pool 2
            count = 0
            pool.on_task_finished { |task| count += 1 }
            pool.process { }
            pool.process { raise }
            wait_until do
                assert_equal 0, pool.backlog
                assert_equal 2, pool.waiting
            end
            assert_equal 2, count
        end

        it "must be able to reque a task" do 
            create_pool 1
            spy.should_receive(:call).twice
            task = pool.process { spy.call }
            wait_until { assert task.finished? }
            pool << task
            wait_until { assert task.finished? }
        end

        it "must process the next task if thread gets available" do 
            create_pool 1
            spy.should_expect do |r|
                r.call(1).once
                r.call(2).once
                r.call(3).once
                r.call(4).once
            end

            pool.process { spy.call(1) }
            pool.process { spy.call(2) }
            pool << Utilrb::ThreadPool::Task.new { spy.call(3) }
            pool << Utilrb::ThreadPool::Task.new { spy.call(4) }
            wait_until do
                assert_equal 0, pool.backlog
                assert_equal 1, pool.waiting
            end
        end
    end

    describe "when shutting down" do
        it "terminates all threads" do 
            create_pool 5
            assert_equal 5, pool.spawned
            pool.shutdown
            pool.join
            assert_equal 0, pool.spawned
        end
    end
end


describe Utilrb::ThreadPool::Task do
    include AsyncWorkHelper

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
                Utilrb::ThreadPool::Task.new bla: 123 do 
                end
            end
        end
        it "must set its options." do
            task = Utilrb::ThreadPool::Task.new sync_key: 2 do 
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
            time = Time.now
            flexmock(Time).should_receive(:now).and_return { time }
            task = Utilrb::ThreadPool::Task.new do 
                time += 0.1
            end
            assert_equal 0, task.time_elapsed

            task.pre_execute
            time += 0.1
            assert_in_delta 0.1, task.time_elapsed, 0.001
            task.execute
            assert_in_delta 0.2, task.time_elapsed, 0.001
            time += 0.1
            assert_in_delta 0.2, task.time_elapsed, 0.001
            task.finalize
            time += 0.1
            assert_in_delta 0.2, task.time_elapsed, 0.001
        end
    end

    describe "when terminated" do
        it "must be in terminated state." do 
            m, c = Mutex.new, ConditionVariable.new
            task = Utilrb::ThreadPool::Task.new do
                m.synchronize { c.wait(m) }
            end
            thread = Thread.new do
                task.pre_execute
                task.execute
                task.finalize
            end
            wait_until do
                assert task.running?
            end
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
                synchronized_work
            end
            thread = Thread.new do
                task.pre_execute
                task.execute
                task.finalize
            end
            wait_synchronized_workers 1
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
end

