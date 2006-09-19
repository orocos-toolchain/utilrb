module Kernel
    # Yields every +cycle+ seconds
    def poll(cycle)
	loop do
	    yield
	    sleep(cycle)
	end
    end
    # Yields every +cycle+ seconds until
    # the block returns true.
    def wait_until(cycle)
        until yield
	    sleep(cycle)
	end
    end
    # Yields every +cycle+ seconds until
    # the block returns false.
    def wait_while(cycle)
        while yield
            sleep(cycle)
        end
    end
end

