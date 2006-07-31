require 'utilrb/object/attribute'

class Module
    # Define 'name' to be a read-only enumerable attribute. The method
    # defines a +attr_name+ read-only attribute and an enumerator method 
    # each_#{name}. +init_block+ is used to initialize the attribute.
    #
    # The enumerator method accepts a +key+ argument. If the attribute is
    # a key => enumerable map, then the +key+ attribute can be used to iterate
    # 
    # +enumerator+ is the name of the enumeration method
    def attr_enumerable(name, attr_name = name, enumerator = :each, &init_block)
	class_eval do
	    attribute(attr_name, &init_block)
	end
        class_eval <<-EOF
            def each_#{name}(key = nil, &iterator)
                return unless #{attr_name}
                if key
                    #{attr_name}[key].#{enumerator}(&iterator)
                else
                    #{attr_name}.#{enumerator}(&iterator)
                end
            end
        EOF
    end
end

