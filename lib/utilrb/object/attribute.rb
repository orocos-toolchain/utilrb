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

	class_eval { attr_writer name }
	define_method(name) do
	    singleton_class.class_eval { attr_reader name }
	    instance_variable_set("@#{name}", defval || (instance_eval(&init) if init))
	end
    end
   
    # Define an attribute on the singleton class
    # See Object::attribute for the definition of
    # default values
    def class_attribute(attr_def, &init)
        if Hash === attr_def
            name, defval = attr_def.to_a.flatten
        else
            name = attr_def
        end

	singleton_class.class_eval do
	    attr_writer name
	    define_method("#{name}_defval") do
		defval || (instance_eval(&init) if init)
	    end
	end

	singleton_class.class_eval <<-EOD
	def #{name}
	    if defined? @#{name} then @#{name}
	    else @#{name} = #{name}_defval
	    end
	end
	EOD
    end
end

