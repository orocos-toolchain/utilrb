class Array
    # Returns a random element of the array
    def random_element; self[rand(size)] end
end

module Enumerable
    # Returns a random element in the enumerable. In the worst case scenario,
    # it converts the enumerable into an array
    def random_element
	if respond_to?(:to_ary)
	    to_ary.random_element
	elsif respond_to?(:size)
	    return if size == 0
	    element = rand(size)
	    each_with_index { |e, i| return e if i == element }
	    raise "something wrong here ..."
	elsif respond_to?(:to_a)
	    to_a.random_element
	else
	    raise ArgumentError, "cannot ue #random_element on this enumerable"
	end
    end
end

