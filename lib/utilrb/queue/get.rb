class Queue
    # Returns all elements currently in the queue.
    # If +non_block+ is true, returns an empty array
    # if the queue is empty
    def get(non_block = false)
	while (Thread.critical = true; @que.empty?)
	    return [] if non_block
	    @waiting.push Thread.current
	    Thread.stop
	end
	result = @que.dup
	@que.clear
	result
    ensure
	Thread.critical = false
    end
end
