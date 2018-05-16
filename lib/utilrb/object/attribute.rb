class Object
    # call-seq:
    #   attribute :name => default_value
    #   attribute(:name) { default_value }
    #
    # In the first form, defines a read-write attribute
    # named 'name' with default_value for default value.
    # In the second form, the block is called if the attribute
    # is read before it has been ever written, and its return
    # value is used as default value.
    def attribute(attr_def, &init) # :nodoc:
        if Hash === attr_def
            name, defval = attr_def.to_a.flatten
        else
            name = attr_def
        end

        class_eval do
            attr_writer name
            if !defval && init
                define_method("#{name}_defval", &init)
            else
                define_method("#{name}_defval") { defval }
            end
        end

        class_eval <<-EOD, __FILE__, __LINE__+1
        def #{name}
            if instance_variable_defined?(:@#{name}) then @#{name}
            elsif frozen?
                #{name}_defval
            else @#{name} = #{name}_defval
            end
        end
        EOD
    end
end

class Object
    # Like #attribute, but on the singleton class of this object
    def class_attribute(attr_def, &init)
	singleton_class.class_eval { attribute(attr_def, &init) }
    end
end
