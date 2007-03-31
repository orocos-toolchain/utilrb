module EnumerableToString
    # This method is a generic implementaion of #to_s on enumerables.
    def self.to_s_helper(enumerable, start, stop, &block)
	stack = (Thread.current[:to_s_helper] ||= [])
	if stack.include?(object_id)
	    "..."
	else
	    begin
		stack.push object_id
		start.dup << enumerable.map(&block).join(", ") << stop
	    ensure
		stack.pop
	    end
	end
    end
end

