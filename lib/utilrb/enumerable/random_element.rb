module Enumerable
    def random_element
	if Array === self
	    self[rand(size)]
	elsif respond_to?(:to_ary)
	    to_ary.random_element
	elsif respond_to?(:size)
	    element = rand(size)
	    each_with_index { |e, i| return e if i == element }
	    nil
	elsif respond_to?(:to_a)
	    to_a.random_element
	end
    end
end

