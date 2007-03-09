class Module
    # Defines a +name+ predicate (name should end with '?'), and if writable is true
    # a writer method which is +name+ without '?'
    #
    # The predicate reads the instance variable which is +name+ without the '?'
    def attr_predicate(name, writable = false)
	attr_name = name.to_s.gsub(/\?$/, '')
	attr_reader attr_name
	alias_method "#{attr_name}?", attr_name
	remove_method attr_name

	if writable
	    class_eval "def #{attr_name}=(value); @#{attr_name} = !!value end"
	end
    end
end

