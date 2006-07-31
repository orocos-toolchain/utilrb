require 'utilrb/object/singleton_class'

class Object
    # :call-seq
    #   attribute :name => default_value
    #   attribute(:name) { default_value }
    #
    # In the first form, defines a read-write attribute
    # named 'name' with default_value for default value.
    # In the second form, the block is called if the attribute
    # is read before it has been ever written, and its return
    # value is used as default value.
    def attribute(attr_def, &init)
        if Hash === attr_def
            name, defval = attr_def.to_a.flatten
        else
            name = attr_def
        end

        iv_name = "@#{name}"
        define_method("#{name}_attribute_init") do
            newval = defval || (instance_eval(&init) if init)
            self.send("#{name}=", newval)
        end

        class_eval <<-EOF
        def #{name}
            if defined? @#{name}
                @#{name}
            else
                #{name}_attribute_init
            end
        end
        attr_writer :#{name}
        EOF
    end
   
    # Define an attribute on the singleton class
    # See Object::attribute for the definition of
    # default values
    def class_attribute(attr_def, &init)
	singleton_class.class_eval do
	    attribute(attr_def, &init)
	end
    end
end

