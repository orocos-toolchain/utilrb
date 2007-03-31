require 'utilrb/enumerable/to_s_helper'
require 'set'
class Set
    # Displays the set as {a, b, c, d}
    def to_s
	EnumerableToString.to_s_helper(self, '{', '}') do |obj|
	    obj.to_s
	end
    end
end

