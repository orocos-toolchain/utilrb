class Array
    # Displays arrays as [ a, b, [c, d], ... ] instead of the standard #join
    # Unlike #inspect, it calls #to_s on the elements too
    def to_s
	stack = (Thread.current[:array_to_s] ||= [])
	if stack.include?(self)
	    "..."
	else
	    begin
		stack.push self
		"[" << map { |obj| obj.to_s }.join(", ") << "]"
	    ensure
		stack.pop
	    end
	end
    end
end

