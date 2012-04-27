class Module
    # Defines a +name?+ predicate, and if writable is true a #name= method.
    # Note that +name+ can end with '?', in which case the ending '?' is
    # removed.
    #
    # The methods use the @name instance variable internally
    def attr_predicate(name, writable = false)
	attr_name = name.to_s.gsub(/\?$/, '')
	attr_reader attr_name
	alias_method "#{attr_name}?", attr_name
	remove_method attr_name

	if writable
	    class_eval "def #{attr_name}=(value); @#{attr_name} = !!value end", __FILE__, __LINE__+1
	end
    end
end

