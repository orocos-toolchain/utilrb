# frozen_string_literal: true

class Module # rubocop:disable Style/Documentation
    # call-seq:
    #   dsl_attribute(name)
    #   dsl_attribute(name,name2,name3)
    #   dsl_attribute(name) { |value| ... }
    #
    # This defines a +name+ instance method on the given class which accepts
    # zero or one argument
    #
    # Without any argument, it acts as a getter for the +@name+ attribute. With
    # one argument, it acts instead as a setter for the same attribute and
    # returns self. If a block has been given to +dsl_attribute+, any new value
    # is passed to the block, whose return value is actually saved in the
    # instance variable.  This block can therefore both filter the value
    # (convert it to a desired form) and validate it.
    #
    # The goal of this method is to have a nicer way to handle attribute in
    # DSLs: instead of
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
    def dsl_attribute(*names, &filter_block)
        if names.size > 1
            if filter_block
                raise ArgumentError,
                      "multiple names as argument are only supported if no block is given"
            end

            names.each { |name| dsl_attribute(name) }
            return
        end

        name = names.first

        class_eval do
            if filter_block
                define_method("__dsl_attribute__#{name}__filter__", &filter_block)
            end

            define_method(name) do |*value, **kw|
                if value.empty? && kw.empty?
                    instance_variable_get("@#{name}")
                elsif filter_block
                    # Ruby 2.7 madness. The second version would pass {} as
                    # second argument
                    filtered_value =
                        if kw.empty?
                            send("__dsl_attribute__#{name}__filter__", *value)
                        else
                            send("__dsl_attribute__#{name}__filter__", *value, **kw)
                        end
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
