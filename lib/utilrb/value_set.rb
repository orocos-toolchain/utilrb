require 'utilrb/common'
require 'utilrb/enumerable/to_s_helper'

Utilrb.require_faster("ValueSet") do
    class ValueSet
	def <<(obj); insert(obj) ; self end
	alias :| :union
	alias :& :intersection
	alias :- :difference
	include Enumerable

	def to_s
	    elements = EnumerableToString.to_s_helper(self, '{', '}') do |obj|
		obj.to_s
	    end
	    base = super[0..-2]
	    "#{base} #{elements}>"
	end
	alias :inspect :to_s

	def _dump(lvl = -1)
	    Marshal.dump(to_a)
	end
	def self._load(str)
	    Marshal.load(str).to_value_set
	end
    end
end
