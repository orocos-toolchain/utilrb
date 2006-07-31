module Kernel
    def poll(cycle)
	loop do
	    yield
	    sleep(cycle)
	end
    end
    def wait_until(cycle)
        until yield
	    sleep(cycle)
	end
    end
    def wait_while(cycle)
        while yield
            sleep(cycle)
        end
    end
end

