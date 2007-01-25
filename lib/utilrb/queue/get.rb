class Queue
    # Returns all elements currently in the queue.  If +non_block+ is true,
    # returns an empty array if the queue is empty
    #
    # WARNING: this method is NOT compatible with fastthread's Queue implementation
    # If you rely on Queue#get and want to use fastthread, you will have to patch
    # fastthread with patches/fastthread-queue-get.patch
    unless instance_methods.include?("get")
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
end
