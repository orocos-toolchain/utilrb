require 'utilrb/enumerable/to_s_helper'
class Array
    # Displays arrays as [ a, b, [c, d], ... ] instead of the standard #join
    # Unlike #inspect, it calls #to_s on the elements too
    def to_s
	EnumerableToString.to_s_helper(self, '[', ']') do |obj|
	    obj.to_s
	end
    end
end

