class Queue
    def get(non_block = false)
	while (Thread.critical = true; @que.empty?)
	    raise ThreadError, "queue empty" if non_block
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
