require 'utilrb/object/attribute'
require 'utilrb/object/singleton_class'
require 'utilrb/enumerable/uniq'
require 'utilrb/module/include'

module Utilrb
module Models
    # Helper method for inherited_enumerable
    #
    # It is called in the context of the singleton class of the module/class on
    # which inherited_enumerable is called
    def define_inherited_enumerable(name, attribute_name = name, options = Hash.new, &init) # :nodoc:
        # Set up the attribute accessor
	attribute(attribute_name, &init)
	class_eval { private "#{attribute_name}=" }

        promote = method_defined?("promote_#{name}")
	options[:enum_with] ||= :each

        class_eval <<-EOF, __FILE__, __LINE__+1
        def all_#{name}; each_#{name}.to_a end
        def self_#{name}; @#{attribute_name} end
        EOF

        if options[:map]
            class_eval <<-EOF, __FILE__, __LINE__+1
            def find_#{name}(key)
                raise ArgumentError, "nil cannot be used as a key in find_#{name}" if !key
                each_#{name}(key, true) do |value|
                    return value
                end
                nil
            end
            def has_#{name}?(key)
                ancestors = self.ancestors
                if ancestors.first != self
                    ancestors.unshift self
                end
                for klass in ancestors
                    if klass.instance_variable_defined?(:@#{attribute_name})
                        return true if klass.#{attribute_name}.has_key?(key)
                    end
                end
                false
            end
            EOF
        end

        if !promote
            if options[:map]
                define_inherited_enumerable_map_without_promotion(name, attribute_name, options)
            else
                define_inherited_enumerable_nomap_without_promotion(name, attribute_name, options)
            end
        else
            if options[:map]
                define_inherited_enumerable_map_with_promotion(name, attribute_name, options)
            else
                define_inherited_enumerable_nomap_with_promotion(name, attribute_name, options)
            end
        end
    end

    def define_inherited_enumerable_map_without_promotion(name, attribute_name, options)
        class_eval <<-EOF, __FILE__, __LINE__+1
        def each_#{name}(key = nil, uniq = true)
            if !block_given?
                return enum_for(:each_#{name}, key, uniq)
            end

            ancestors = self.ancestors
            if ancestors.first != self
                ancestors.unshift self
            end
            if key
                for klass in ancestors
                    if klass.instance_variable_defined?(:@#{attribute_name})
                        if klass.#{attribute_name}.has_key?(key)
                            yield(klass.#{attribute_name}[key])
                            return self if uniq
                        end
                    end
                end
            elsif !uniq
                for klass in ancestors
                    if klass.instance_variable_defined?(:@#{attribute_name})
                        klass.#{attribute_name}.#{options[:enum_with]} do |el|
                            yield(el)
                        end
                    end
                end
            else
                seen = Set.new
                for klass in ancestors
                    if klass.instance_variable_defined?(:@#{attribute_name})
                        klass.#{attribute_name}.#{options[:enum_with]} do |el| 
                            unless seen.include?(el.first)
                                seen << el.first
                                yield(el)
                            end
                        end
                    end
                end

            end
            self
        end
        EOF
    end

    def define_inherited_enumerable_nomap_without_promotion(name, attribute_name, options)
        class_eval <<-EOF, __FILE__, __LINE__+1
        def each_#{name}
            if !block_given?
                return enum_for(:each_#{name})
            end

            ancestors = self.ancestors
            if ancestors.first != self
                ancestors.unshift self
            end
            for klass in ancestors
                if klass.instance_variable_defined?(:@#{attribute_name})
                    klass.#{attribute_name}.#{options[:enum_with]} { |el| yield(el) }
                end
            end
            self
        end
        EOF
    end

    def define_inherited_enumerable_map_with_promotion(name, attribute_name, options)
        class_eval <<-EOF, __FILE__, __LINE__+1
        def each_#{name}(key = nil, uniq = true)
            if !block_given?
                return enum_for(:each_#{name}, key, uniq)
            end

            ancestors = self.ancestors
            if ancestors.first != self
                ancestors.unshift self
            end
            if key
                promotions = []
                for klass in ancestors
                    if klass.instance_variable_defined?(:@#{attribute_name})
                        if klass.#{attribute_name}.has_key?(key)
                            value = klass.#{attribute_name}[key]
                            for p in promotions
                                value = p.promote_#{name}(key, value)
                            end
                            yield(value)
                            return self if uniq
                        end
                    end
                    promotions.unshift(klass) if klass.respond_to?("promote_#{name}")
                end
            elsif !uniq
                promotions = []
                for klass in ancestors
                    if klass.instance_variable_defined?(:@#{attribute_name})
                        klass.#{attribute_name}.#{options[:enum_with]} do |key, value|
                            for p in promotions
                                value = p.promote_#{name}(key, value)
                            end
                            yield(key, value)
                        end
                    end
                    promotions.unshift(klass) if klass.respond_to?("promote_#{name}")
                end
            else
                seen = Set.new
                promotions = []
                for klass in ancestors
                    if klass.instance_variable_defined?(:@#{attribute_name})
                        klass.#{attribute_name}.#{options[:enum_with]} do |key, value|
                            unless seen.include?(key)
                                for p in promotions
                                    value = p.promote_#{name}(key, value)
                                end
                                seen << key
                                yield(key, value)
                            end
                        end
                    end
                    promotions.unshift(klass) if klass.respond_to?("promote_#{name}")
                end
            end
            self
        end
        EOF
    end

    def define_inherited_enumerable_nomap_with_promotion(name, attribute_name, options)
        class_eval <<-EOF, __FILE__, __LINE__+1
        def each_#{name}
            if !block_given?
                return enum_for(:each_#{name})
            end

            ancestors = self.ancestors
            if ancestors.first != self
                ancestors.unshift self
            end
            promotions = []
            for klass in ancestors
                if klass.instance_variable_defined?(:@#{attribute_name})
                    klass.#{attribute_name}.#{options[:enum_with]} do |value|
                        for p in promotions
                            value = p.promote_#{name}(value)
                        end
                        yield(value)
                    end
                end
                promotions.unshift(klass) if klass.respond_to?("promote_#{name}")
            end
            self
        end
        EOF
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
    # === Example
    # Let's define some classes and look at the ancestor chain
    #
    #   class A;  end
    #   module M; end
    #   class B < A; include M end
    #   A.ancestors # => [A, Object, Kernel]
    #   B.ancestors # => [B, M, A, Object, Kernel]
    #
    # ==== Attributes for which 'map' is not set
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
    # ==== Attributes for which 'map' is set
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
	    unless const_defined_here?(:ClassExtension)
		const_set(:ClassExtension, Module.new)
	    end
	    class_extension = const_get(:ClassExtension)
	    class_extension.class_eval do
		define_inherited_enumerable(name, attribute_name, options, &init)
	    end
	end
    end
end
end

