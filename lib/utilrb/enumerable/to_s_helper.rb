module EnumerableToString
    # This method is a generic implementaion of #to_s on enumerables.
    def self.to_s_helper(enumerable, start, stop)
	stack = (Thread.current[:to_s_helper] ||= [])
	if stack.include?(enumerable.object_id)
	    "..."
	else
	    begin
		stack.push enumerable.object_id
		start.dup << enumerable.map { |el| yield(el) }.join(", ") << stop
	    ensure
		stack.pop
	    end
	end
    end
end

