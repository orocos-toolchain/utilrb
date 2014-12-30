require 'utilrb/test'
require 'utilrb/thread_pool'
require 'minitest/spec'

module ThreadPoolHelpers
    def setup
        @mutex = Mutex.new
        @cv = ConditionVariable.new
        @waiting_threads = Set.new
        @blocked_threads = Set.new
        super
    end

    # Check that {pool} ends up in a state where a certain number of threads are
    # blocked in processing and the rest sleep waiting for work
    #
    # For this to work, one must only use {wait} or {block} to put a work thread
    # to sleep
    #
    # @param [Integer] expected_tasks the number of thread that should end up
    #   sleeping while processing their work block
    #
    # @param [Integer] timeout waiting to reach the expected state, in seconds
    #
    # @example wait for a process block to sleep
    #   pool.process { wait }
    #   assert_tasks_sleep_in_process_block(1)
    #   # At this point, one thread is processing the block above *and* is
    #   # sleeping within the 'wait' call. The rest of the threads are waiting
    #   # for work
    #
    #   # This will wake up the sleeping work thread
    #   broadcast
    #   # And this waits for the work thread to finalize its task and
    #   # get back to waiting for more work
    #   assert_tasks_sleep_in_process_block(0)
    def assert_tasks_sleep_in_process_block(expected_tasks, timeout = 1)
        start_time = Time.now
        while true
            if Time.now - start_time > timeout
                blocked_or_waiting = @waiting_threads.size +
                    @blocked_threads.size
                sleeping_workers = pool.workers.count { |t| t.status == 'sleep' }
                flunk("pool did not reach #{expected_tasks} processing tasks in sleep state: #{@blocked_threads.size} are blocked in their process block, #{@waiting_threads.size} are waiting in their process block; among #{pool.workers.size} spawned workers #{sleeping_workers} are currently sleeping and #{pool.waiting_threads} are waiting for work")
            end

            done = @mutex.synchronize do
                blocked_or_waiting = @waiting_threads.size +
                    @blocked_threads.size

                (blocked_or_waiting == expected_tasks) &&
                    (pool.waiting_threads + expected_tasks == pool.spawned_threads) &&
                    pool.workers.all? { |t| t.status == 'sleep' }

            end
            if done
                return
            end
            Thread.pass
        end
    end

    # Helper method to implement test-related blocking behaviour in process
    # blocks
    #
    # @see wait block
    def process_and_block(set)
        begin
            t = Thread.current
            set << t
            while set.include?(t)
                yield
            end
        ensure
            set.delete t
        end
    end

    # Call in a process block for it to block and wait for #broadcast to be
    # called in a way that's friendly to {assert_tasks_sleep_in_process_block}
    def wait
        @mutex.synchronize do
            process_and_block(@waiting_threads) { @cv.wait(@mutex) }
        end
    end

    # Call in a process block for it to block forever in a way that's friendly
    # to {assert_tasks_sleep_in_process_block}
    def block
        @mutex.synchronize do
            process_and_block(@blocked_threads) do
                begin
                    @mutex.unlock
                    sleep
                ensure
                    @mutex.lock
                end
            end
        end
    end

    # Wake up all process blocks that are blocked by {wait} in a way that's
    # friendly to {assert_tasks_sleep_in_process_block}
    def broadcast
        @mutex.synchronize do
            @waiting_threads.clear
            @cv.broadcast
        end
    end

    # Wait for the provided thread to be in sleep state
    def wait_thread_sleeps(thread)
        while true
            if thread.status == 'sleep'
                break
            end
            Thread.pass
        end
    end
end

describe Utilrb::ThreadPool do
    include ThreadPoolHelpers

    def pool
        @pool ||= Utilrb::ThreadPool.new(5)
    end

    after do
        broadcast
        if @pool
            pool.shutdown
            #pool.join
        end
    end

    describe "#initalize" do
        it "creates the minimum number of threads" do 
            assert_equal 5, pool.spawned
        end
    end

    describe "#process" do
        describe "before the threads started processing" do
            it "has all threads in spawned and all tasks in backlog" do
                # Basically disable the internal handling in #spawn_thread
                pool.disable_processing
                8.times do
                    pool.process { }
                end
                assert_equal 8,pool.backlog
            end
        end

        describe "if there are more tasks than threads" do
            it "has all threads in spawned and remaining tasks in backlog" do
                8.times do
                    pool.process { wait }
                end
                assert_tasks_sleep_in_process_block(5)
                assert_equal 3,pool.backlog
                assert_equal 0,pool.waiting
                assert_equal 5,pool.spawned
                assert_equal 5,pool.running
            end
        end

        describe "if there are more threads than tasks" do
            it "has all threads in spawned and unused threads in waiting" do
                3.times do
                    pool.process { block }
                end
                assert_tasks_sleep_in_process_block(3)
                assert_equal 0,pool.backlog
                assert_equal 2,pool.waiting
                assert_equal 5,pool.spawned
                assert_equal 3,pool.running
            end
        end
    end

    describe "#resize" do
        describe "increasing the max number of threads" do
            it "spawns threads as required by the waiting tasks" do 
                8.times do
                    pool.process { block }
                end
                assert_tasks_sleep_in_process_block(5)

                pool.resize(5,10)
                assert_tasks_sleep_in_process_block(8)

                assert_equal 8,pool.spawned
                assert_equal 0,pool.backlog
                assert_equal 0,pool.waiting
                assert_equal 8,pool.running
            end

            it "does not spawn more than max threads" do
                8.times do
                    pool.process { block }
                end
                assert_tasks_sleep_in_process_block(5)

                pool.resize(5,6)
                assert_tasks_sleep_in_process_block(6)

                assert_equal 6,pool.spawned
                assert_equal 2,pool.backlog
                assert_equal 0,pool.waiting
                assert_equal 6,pool.running
            end

            it "trims threads that are above the limit" do
                8.times do
                    pool.process { }
                end
                assert_tasks_sleep_in_process_block(0)

                pool.resize(2,3)
                assert_tasks_sleep_in_process_block(0)

                assert_equal 3,pool.spawned
                assert_equal 0,pool.backlog
                assert_equal 3,pool.waiting
                assert_equal 0,pool.running
            end
        end
    end

    describe "the auto_trim parameter" do
        before do
            pool.resize(5, 10)
        end
        describe "it is true" do
            before do
                pool.resize(5, 10)
                pool.auto_trim = true
            end
            it "the pool reduces its size after the work is done" do
                5.times { pool.process { block } }
                3.times.map { pool.process { wait } }
                assert_tasks_sleep_in_process_block(8)
                broadcast
                assert_tasks_sleep_in_process_block(5)
                assert_equal 5,pool.spawned_threads
                assert_equal 0,pool.waiting_threads
            end
            it "does not reduce the size below the low limit" do
                3.times { pool.process { block } }
                5.times { pool.process { wait } }
                assert_tasks_sleep_in_process_block(8)
                broadcast
                assert_tasks_sleep_in_process_block(3)
                assert_equal 5,pool.spawned_threads
                assert_equal 2,pool.waiting_threads
            end
        end

        describe "it is false" do
            before do
                pool.auto_trim = false
            end
            it "does not reduce its size" do
                5.times { pool.process { block } }
                3.times { pool.process { wait } }
                assert_tasks_sleep_in_process_block(8)
                broadcast
                assert_tasks_sleep_in_process_block(5)
                assert_equal 8,pool.spawned_threads
                assert_equal 3,pool.waiting_threads
            end
        end
    end

    describe "the execution logic" do
        it "does not execute tasks with the same key in parallel" do
            50.times do |i|
                pool.process_with_options :sync_key => 1 do
                    wait
                end
            end
            assert_tasks_sleep_in_process_block(1)
            50.times do |i|
                assert_equal (50 - i - 1), pool.backlog
                assert_equal 1, pool.running
                broadcast
                if i != 49
                    assert_tasks_sleep_in_process_block(1)
                end
            end
        end

        it "must execute a task and a sync call in parallel if they have different sync keys" do
            pool.process_with_options :sync_key => 1 do
                wait
            end
            assert_tasks_sleep_in_process_block(1)
            # This will block forever if parallel execution is not possible
            pool.sync(2) { }
            broadcast
            # !! DO NOT use #process_all_pending_work
            # Since the two tasks are supposed to be executed in parallel,
            # calling #broadcast and #wait_pool_sleeps must be enough to
            # process everything
            assert_tasks_sleep_in_process_block(0)
        end
    end

    describe "#on_task_finished" do
        it "sets up the block to be called when task finish normally" do
            finished = Queue.new
            pool.on_task_finished do |task|
                finished << task
            end
            tasks = 10.times.map do |i|
                pool.process { }
            end
            finished_tasks = Timeout.timeout(1) do
                10.times.map do
                    finished.pop
                end
            end
            assert_equal tasks.to_set, finished_tasks.to_set
        end

        it "sets up the block to be called when task finishes with an exception" do
            finished = Queue.new
            pool.on_task_finished do |task|
                finished << task
            end
            tasks = 10.times.map do |i|
                pool.process { raise }
            end
            finished_tasks = Timeout.timeout(1) do
                10.times.map do
                    finished.pop
                end
            end
            assert_equal tasks.to_set, finished_tasks.to_set
        end

        it "executes all queued tasks, waiting for threads if needed" do
            mock = flexmock
            20.times do |i|
                mock.should_receive(:called).with(i).once
                pool.process do
                    mock.called(i)
                end
            end
            pool.process_all_pending_work
        end
    end

    describe "#<<" do
        it "raises if one tries to queue an already-queued task" do
            pool.disable_processing
            task = pool.process { }
            assert_raises(Utilrb::ThreadPool::Task::AlreadyInUse) do
                pool << task
            end
        end
        it "reques an existing task" do 
            recorder = flexmock
            recorder.should_receive(:called).with(0).once
            recorder.should_receive(:called).with(1).once
            id = 0
            task = pool.process { recorder.called(id) }
            pool.process_all_pending_work
            id = 1
            pool << task
            pool.process_all_pending_work
        end
    end

    describe "#shutdown" do
        it "terminates all threads" do 
            pool = Utilrb::ThreadPool.new(5)
            pool.shutdown
            pool.join
            assert pool.workers.empty?
        end
    end

    describe "#join" do
        it "raises ArgumentError if called without #shutdown first" do
            assert_raises(ArgumentError) { pool.join }
        end
    end
end


describe Utilrb::ThreadPool::Task do
    include ThreadPoolHelpers

    def assert_task_state(task, *states)
        all_states = [:queued, :running, :finished, :exception, :terminated, :successfull, :started]
        (all_states - states).each do |s|
            assert !task.send("#{s}?"), "state #{s}? unexpectedly set on #{task}"
        end
        states.each do |s|
            assert task.send("#{s}?"), "state #{s}? unexpectedly unset on #{task}"
        end
    end

    describe "#initialize" do
        it "raises if no block is given." do 
            assert_raises(ArgumentError) do
                Utilrb::ThreadPool::Task.new
            end
        end
        it "sets the task in waiting state." do 
            task = Utilrb::ThreadPool::Task.new do 
            end
            assert_task_state(task)
            assert_equal :waiting, task.state
        end
        it "sets the sync_key option if given" do
            task = Utilrb::ThreadPool::Task.new :sync_key => 2 do 
                123
            end
            assert_equal 2, task.sync_key
        end
    end

    describe "#acquire" do
        it "sets the state to waiting" do
            task = Utilrb::ThreadPool::Task.new { }
            task.pre_execute
            task.execute
            task.finalize
            task.acquire
            assert_task_state(task, :queued)
            assert_equal :waiting, task.state
        end
    end

    describe "#pre_execute" do
        it "sets the state to running" do
            task = Utilrb::ThreadPool::Task.new { }
            task.pre_execute
            assert_task_state(task, :started, :running)
        end
    end

    describe "#finalize" do
        def prepare_task(options = Hash.new)
            task = Utilrb::ThreadPool::Task.new(options, &proc)
            task.pre_execute
            task.execute
            task
        end

        it "sets the task in finished state if the work did not raise" do
            task = prepare_task { 123 }
            task.finalize
            assert_task_state(task, :started, :finished, :successfull)
        end

        it "calls the registered callback" do 
            task = prepare_task { 123 }
            mock = flexmock
            mock.should_receive(:called).with(123, nil).once
            task.callback do |val, e|
                mock.called(val, e)
            end
            task.finalize
        end

        describe "an exception being raised by the work block" do
            it "sets the task to exception state" do 
                task = prepare_task { raise }
                task.finalize
                assert_task_state(task, :started, :finished, :exception)
            end

            it "passes the exception to the callback" do
                error = Exception.new
                task = prepare_task { raise error }

                mock = flexmock
                mock.should_receive(:called).with(nil, error).once
                task.callback do |val, e|
                    mock.called(val, e)
                end
                task.finalize
            end

            it "passes both the default value and the error to the callback" do 
                error = Exception.new
                task = prepare_task(:default => 123) { raise error }

                mock = flexmock
                mock.should_receive(:called).with(123, error).once
                task.callback do |val,e|
                    mock.called(val, e)
                end
                task.finalize
            end
        end
    end

    it "calculates the time spent during execution" do 
        task = Utilrb::ThreadPool::Task.new do 
            sleep 0.2
        end
        assert_in_delta 0.0,task.time_elapsed,0.0001
        thread = Thread.new do 
            start_time = Time.now
            task.pre_execute
            task.execute
            task.finalize
            (Time.now - start_time)
        end
        time_spent = thread.value
        # !! time_spent MUST be called separately as it ensures that the thread
        # !! finished
        assert_in_delta time_spent, task.time_elapsed, 0.01
    end

    describe "#terminate!" do
        it "sets the task to terminated state" do 
            task = Utilrb::ThreadPool::Task.new do 
                sleep
            end
            thread = Thread.new do
                task.pre_execute
                task.execute
                task.finalize
            end
            wait_thread_sleeps(thread)
            task.terminate!
            thread.join

            assert_task_state(task, :started, :finished, :terminated)
        end
    end

    describe "#wait" do
        attr_reader :task

        before do
            @task = Utilrb::ThreadPool::Task.new { }
        end

        describe "a task in pending state" do
            it "should block the caller and wake it up when the task finishes" do
                thread = Thread.new { task.wait; sleep }
                wait_thread_sleeps(thread)
                task.pre_execute
                task.execute
                assert_equal 'sleep', thread.status
                task.finalize
                assert_equal 'run', thread.status
                Timeout.timeout(1) do
                    thread.raise RuntimeError
                    thread.join rescue nil
                end
            end
        end
        describe "a task in running state" do
            it "should block the caller and wake it up when the task finishes" do
                task.pre_execute
                thread = Thread.new { task.wait; sleep }
                wait_thread_sleeps(thread)
                task.execute
                assert_equal 'sleep', thread.status
                task.finalize
                assert_equal 'run', thread.status
                Timeout.timeout(1) do
                    thread.raise RuntimeError
                    thread.join rescue nil
                end
            end
        end
        describe "a finished task not yet finalized" do
            it "should block the caller and wake it up when the task finishes" do
                task.pre_execute
                task.execute
                thread = Thread.new { task.wait; sleep }
                wait_thread_sleeps(thread)
                task.finalize
                assert_equal 'run', thread.status
                Timeout.timeout(1) do
                    thread.raise RuntimeError
                    thread.join rescue nil
                end
            end
        end
        describe "a task in finished state" do
            it "should return right away" do
                task.pre_execute
                task.execute
                task.finalize
                Timeout.timeout(1) do
                    task.wait
                end
            end
        end
    end
end

