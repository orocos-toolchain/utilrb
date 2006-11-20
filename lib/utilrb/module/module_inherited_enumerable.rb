require 'utilrb/object/attribute'
require 'utilrb/enumerable/uniq'

class Module
    # Defines an attribute as being enumerable in the class instance and in the
    # whole class inheritance hierarchy.  More specifically, it defines a
    # <tt>each_#{name}(&iterator)</tt> instance method and a <tt>each_#{name}(&iterator)</tt>
    # class method which iterates (in order) on 
    # - the instance #{name} attribute
    # - the singleton class #{name} attribute
    # - the class #{name} attribute
    # - the superclass #{name} attribute
    # - the superclass' superclass #{name} attribute
    # ...
    #
    # The +name+ option defines the enumeration method name (+value+ will
    # define a +each_value+ method). +attribute_name+ defines the attribute
    # name. +init+ is a block called to initialize the attribute. 
    # Valid options in +options+ are: 
    # map:: the attribute should respond to +[]+. The enumeration method takes two 
    #	    arguments, +key+ and +uniq+. If +key+ is given, we iterate on the values
    #	    given by <tt>attribute[key]</tt>. If +uniq+ is true, the enumeration will
    #	    yield at most one value for each +key+ found (so, if both +key+ and +uniq+ are
    #	    given, the enumeration yields at most one value)
    #
    # For instance
    #
    #	class A 
    #	    class_inherited_enumerable("value", "enum") { Array.new }
    #	end
    #	class B < A
    #	end
    #	b = B.new
    #
    #	A.enum << 1
    #	B.enum << 2
    #	class << b
    #	    enum << 3
    #	end
    #
    #	A.each_enum => 1
    #	B.each_enum => 2, 1
    #	b.singleton_class.each_enum => 3, 2, 1
    #
    def module_inherited_enumerable(name, attribute_name = name, options = Hash.new, &init)
        # Set up the attribute accessor
	attribute(attribute_name, &init)
	class_eval { private "#{attribute_name}=" }

	options[:enum_with] ||= :each

        if options[:map]
            class_eval <<-EOF
            def each_#{name}(key = nil, uniq = true)
		if key
		    if #{attribute_name}.has_key?(key)
			yield(#{attribute_name}[key])
			return self if uniq
		    end
		elsif uniq
		    @enum_#{name}_uniq ||= enum_uniq(:each_#{name}, nil, false) { |k, v| k }
		    @enum_#{name}_uniq.each { |el| yield(el) }
		    return self
		else
                    #{attribute_name}.#{options[:enum_with]} { |el| yield(el) }
		end
		superclass.each_#{name}(key, uniq) { |el| yield(el) } if superclass.respond_to?(:each_#{name})
                self
            end
            def has_#{name}?(key)
                return true if #{attribute_name}[key]
		superclass.has_#{name}?(key)
            end
            EOF
        else
            class_eval <<-EOF
            def each_#{name}(&iterator)
                #{attribute_name}.#{options[:enum_with]}(&iterator) if #{attribute_name}
		superclass.each_#{name}(&iterator) if superclass.respond_to?(:each_#{name})
                self
            end
            EOF
        end
    end
end




