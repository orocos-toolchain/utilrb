class Module
    # call-seq:
    #   dsl_attribute(name)
    #   dsl_attribute(name) { |value| ... }
    #
    # This defines a +name+ instance method on the given class which accepts zero or one argument
    #
    # Without any argument, it acts as a getter for the +@name+ attribute. With
    # one argument, it acts instead as a setter for the same attribute and
    # returns self. If a block has been given to +dsl_attribute+, any new value
    # is passed to the block, whose return value is actually saved in the
    # instance variable.  This block can therefore both filter the value
    # (convert it to a desired form) and validate it.
    #
    # The goal of this method is to have a nicer way to handle attribute in DSLs: instead
    # of 
    #
    #    model = create_model do
    #	    self.my_model_attribute = 'bla'
    #
    #	    if (my_model_attribute)
    #		<do something>
    #	    end
    #	 end
    #
    # (or worse, using set_ and get_ prefixes), we can do
    #
    #    model = create_model do
    #	    my_model_attribute 'bla', arg0, arg1, ...
    #
    #	    if (my_model_attribute)
    #		<do something>
    #	    end
    #	 end
    #
    def dsl_attribute(name, &filter_block)
	class_eval do
            if filter_block
                define_method("__dsl_attribute__#{name}__filter__", &filter_block)
            end

	    define_method(name) do |*value|
		if value.empty?
		    instance_variable_get("@#{name}")
		elsif filter_block
                    if filter_block.arity >= 0 && value.size != filter_block.arity
                        raise ArgumentError, "too much arguments. Got #{value.size}, expected #{filter_block.arity}"
                    end

		    filtered_value = send("__dsl_attribute__#{name}__filter__", *value)
		    instance_variable_set("@#{name}", filtered_value)
		    self
		else
                    if value.size == 1
                        instance_variable_set("@#{name}", value.first)
                    else
                        instance_variable_set("@#{name}", value)
                    end
		    self
		end
	    end
	end
    end
end

