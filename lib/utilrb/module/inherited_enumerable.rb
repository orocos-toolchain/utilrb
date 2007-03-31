require 'utilrb/object/attribute'
require 'utilrb/object/singleton_class'
require 'utilrb/enumerable/uniq'
require 'utilrb/module/include'

class Module
    def define_inherited_enumerable(name, attribute_name = name, options = Hash.new, &init) # :nodoc:
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
		if superclass = ancestors[1..-1].find { |k| k.respond_to?(:each_#{name}) }
		    superclass.each_#{name}(key, uniq) { |el| yield(el) }
		end
                self
            end
            def has_#{name}?(key)
                return true if #{attribute_name}[key]
		if superclass = ancestors[1..-1].find { |k| k.respond_to?(:has_#{name}) }
		    superclass.has_#{name}(key)
		end
            end
            EOF
        else
            class_eval <<-EOF
            def each_#{name}(&iterator)
                #{attribute_name}.#{options[:enum_with]}(&iterator) if #{attribute_name}
		if superclass = ancestors[1..-1].find { |k| k.respond_to?(:each_#{name}) }
		    superclass.each_#{name} { |el| yield(el) }
		end
                self
            end
            EOF
        end
    end

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
    # This method can be used on modules, in which case the module is used as if 
    # it was part of the inheritance hierarchy.
    #
    # The +name+ option defines the enumeration method name (+value+ will
    # define a +each_value+ method). +attribute_name+ defines the attribute
    # name. +init+ is a block called to initialize the attribute. 
    # Valid options in +options+ are: 
    # map:: 
    #   If true, the attribute should respond to +[]+. In that case, the
    #   enumeration method is each_value(key = nil, uniq = false) If +key+ is
    #   given, we iterate on the values given by <tt>attribute[key]</tt>. If
    #   +uniq+ is true, the enumeration will yield at most one value for each
    #   +key+ found (so, if both +key+ and +uniq+ are given, the enumeration
    #   yields at most one value). See the examples below
    # enum_with:: the enumeration method of the enumerable, if it is not +each+
    #
    # == Example
    # Let's define some classes and look at the ancestor chain
    #
    #   class A;  end
    #   module M; end
    #   class B < A; include M end
    #   A.ancestors # => [A, Object, Kernel]
    #   B.ancestors # => [B, M, A, Object, Kernel]
    #
    # === Attributes for which 'map' is not set
    #
    #   class A
    #     inherited_enumerable("value", "values") do
    #         Array.new
    #     end
    #   end
    #   module M
    #     inherited_enumerable("mod") do
    #         Array.new
    #     end
    #   end
    #   
    #   A.values << 1 # => [1]
    #   B.values << 2 # => [2]
    #   M.mod << 1 # => [1]
    #   b = B.new 
    #   class << b
    #       self.values << 3 # => [3]
    #       self.mod << 4 # => [4]
    #   end
    #   M.mod << 2 # => [1, 2]
    #   
    #   A.enum_for(:each_value).to_a # => [1]
    #   B.enum_for(:each_value).to_a # => [2, 1]
    #   b.singleton_class.enum_for(:each_value).to_a # => [3, 2, 1]
    #   b.singleton_class.enum_for(:each_mod).to_a # => [4, 1, 2]
    #
    # === Attributes for which 'map' is set
    #
    #   class A
    #     inherited_enumerable("mapped", "map", :map => true) do
    #         Hash.new { |h, k| h[k] = Array.new }
    #     end
    #   end
    #   
    #   A.map['name'] = 'A' # => "A"
    #   A.map['universe'] = 42
    #   B.map['name'] = 'B' # => "B"
    #   B.map['half_of_it'] = 21
    #   
    # Let's see what happens if we don't specify the key option.  
    #   A.enum_for(:each_mapped).to_a # => [["name", "A"], ["universe", 42]]
    # If the +uniq+ option is set (the default), we see only B's value for 'name'
    #   B.enum_for(:each_mapped).to_a # => [["half_of_it", 21], ["name", "B"], ["universe", 42]]
    # If the +uniq+ option is not set, we see both values for 'name'. Note that
    # since 'map' is a Hash, the order of keys in one class is not guaranteed.
    # Nonetheless, we have the guarantee that values from B appear before
    # those from A
    #   B.enum_for(:each_mapped, nil, false).to_a # => [["half_of_it", 21], ["name", "B"], ["name", "A"], ["universe", 42]]
    #
    #
    # Now, let's see how 'key' behaves
    #   A.enum_for(:each_mapped, 'name').to_a # => ["A"]
    #   B.enum_for(:each_mapped, 'name').to_a # => ["B"]
    #   B.enum_for(:each_mapped, 'name', false).to_a # => ["B", "A"]
    #
    def inherited_enumerable(name, attribute_name = name, options = Hash.new, &init)
	singleton_class.class_eval { define_inherited_enumerable(name, attribute_name, options, &init) }

	if is_a?(Module) && !is_a?(Class)
	    unless const_defined?(:ClassExtension)
		const_set(:ClassExtension, Module.new)
	    end
	    class_extension = const_get(:ClassExtension)
	    class_extension.class_eval do
		define_inherited_enumerable(name, attribute_name, options, &init)
	    end
	end
    end
end




