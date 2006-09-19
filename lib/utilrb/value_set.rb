require 'utilrb/common'

Utilrb.require_faster("ValueSet") do
    class ValueSet
	def <<(obj); insert(obj) ; self end
	alias :| :union
	alias :& :intersection
	alias :- :difference
	include Enumerable
    end
end
