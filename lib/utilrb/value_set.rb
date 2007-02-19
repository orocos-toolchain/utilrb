require 'utilrb/common'

Utilrb.require_faster("ValueSet") do
    class ValueSet
	def <<(obj); insert(obj) ; self end
	alias :| :union
	alias :& :intersection
	alias :- :difference
	include Enumerable

	def to_s
	    base = super[0..-2]
	    "#{base} { #{to_a.map { |o| o.to_s }.join(", ")} }"
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
