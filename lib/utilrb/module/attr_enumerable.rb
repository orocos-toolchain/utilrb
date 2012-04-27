require 'utilrb/object/attribute'

class Module
    # Support for attributes that are enumerables. This methods defines two
    # methods:
    #   obj.attr_name # => enumerable
    #   obj.each_name(key = nil) { |value| ... } # => obj
    #
    # The first one returns the enumerable object itself. The second one
    # iterates on the values in attr_name. If +key+ is not nil, then #attr_name
    # is supposed to be a hash of enumerables, and +key+ is used to select the
    # enumerable to iterate on. 
    #
    # The following calls are equivalent
    #   obj.attr_name.each { |value| ... }
    #   obj.each_name { |value| ... }
    #
    # And these two are equivalent:
    #   obj.attr_name[key].each { |value| ... }
    #   obj.each_name(key) { |value| ... }
    #
    # +enumerator+ is the name of the enumeration method we should use.
    # +init_block+, if given, should return the value at which we should
    # initialize #attr_name. 
    def attr_enumerable(name, attr_name = name, enumerator = :each, &init_block)
	class_eval do
	    attribute(attr_name, &init_block)
	end
        class_eval <<-EOF, __FILE__, __LINE__+1
            def each_#{name}(key = nil, &iterator)
                return unless #{attr_name}
                if key
                    #{attr_name}[key].#{enumerator}(&iterator)
                else
                    #{attr_name}.#{enumerator}(&iterator)
                end
		self
            end
        EOF
    end
end

