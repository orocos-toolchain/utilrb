require 'enumerable/to_s_helper'
require 'set'
class Set
    def to_s
	EnumerableToString.to_s_helper(self, '{', '}') do |obj|
	    obj.to_s
	end
    end
end

