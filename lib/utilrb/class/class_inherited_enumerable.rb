require 'utilrb/object/attribute'
require 'utilrb/enumerable/uniq'

class Class
    # Defines an attribute as being enumerable in the class
    # instance and in the whole class inheritance hierarchy
    # 
    # More specifically, it defines
    # a each_#{name}(&iterator) instance method and a 
    # each_#{name}(&iterator) class
    # method which iterates (in order) on 
    # - the class instance #{name} attribute
    # - the singleton class #{name} attribute
    # - the class #{name} attribute
    # - the superclass #{name} attribute
    # - the superclass' superclass #{name} attribute
    # ...
    #
    # It defines also #{name} as a readonly attribute
    def class_inherited_enumerable(name, attribute_name = name, options = Hash.new, &init)
        # Set up the attribute accessor
	class_attribute(attribute_name, &init)
	singleton_class.class_eval { private "#{attribute_name}=" }

	options[:enum_with] ||= :each

        if options[:map]
            singleton_class.class_eval <<-EOF
            def each_#{name}(key = nil, uniq = true, &iterator)
		if key
		    if #{attribute_name}.has_key?(key)
			iterator[#{attribute_name}[key]] 
			return self if uniq
		    end
		elsif uniq
		    enum_uniq(:each_#{name}, nil, false) { |k, v| k }.
			each(&iterator)
		    return self
		else
                    #{attribute_name}.#{options[:enum_with]}(&iterator)
		end
		superclass_call(:each_#{name}, key, uniq, &iterator)
                self
            end
            def has_#{name}?(key)
                return true if #{attribute_name}[key]
		superclass_call(:has_#{name}, key)
            end
            EOF
        else
            singleton_class.class_eval <<-EOF
            def each_#{name}(&iterator)
                #{attribute_name}.#{options[:enum_with]}(&iterator) if #{attribute_name}
		superclass_call(:each_#{name}, &iterator)
                self
            end
            EOF
        end
    end
end



