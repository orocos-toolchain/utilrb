require 'utilrb/enumerable/to_s_helper'
class Hash
    # Displays hashes as { a => A, b => B, ... } instead of the standard #join
    # Unlike #inspect, it calls #to_s on the elements too
    def to_s
	EnumerableToString.to_s_helper(self, '{', '}') do |k, v| 
	    "#{k} => #{v}" 
	end
    end
end

