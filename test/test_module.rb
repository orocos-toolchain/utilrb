require 'test_config'

require 'flexmock'
require 'set'
require 'enumerator'
require 'utilrb/module'

class TC_Module < Test::Unit::TestCase
    def test_include
	class_extension = Module.new do
	    def tag; end
	end

	m = Module.new do
	    const_set(:ClassExtension, class_extension)
	end
	
	m2 = Module.new { include m }
	assert(m2::ClassExtension.method_defined?(:tag))
	k = Class.new do
	    include m2
	end
	assert(k.respond_to?(:tag))
    end

    def test_define_method_with_block
	FlexMock.use do |mock|
	    mock.should_receive(:called).once
	    block_obj = lambda { mock.called }
	    test_obj = self
	    method = lambda do |block, a, b|
		test_obj.assert_equal(a, 1)
		test_obj.assert_equal(b, 2)
		test_obj.assert_equal(block, block_obj)
		block_obj.call
	    end

	    klass = Class.new do
		define_method_with_block(:call, &method)
	    end
	    klass.new.call(1, 2, &block_obj)
	end
    end

    def test_attr_enumerable
        klass = Class.new do
            attr_enumerable(:mapped, :map) { Hash.new }
        end

        obj = klass.new
        obj.map[:a] = [10, 20]
        obj.map[:b] = 10
        assert_equal( [[:a, [10, 20]], [:b, 10]].to_set, obj.enum_for(:each_mapped).to_set )
        assert_equal( [10, 20], obj.enum_for(:each_mapped, :a).to_a )
    end

    def test_inherited_enumerable_module
        m = Module.new do
            inherited_enumerable(:signature, :signatures) { Array.new }
        end
        k = Class.new do
            include m
            inherited_enumerable(:child_attribute) { Array.new }
        end

        # Add another attribute *after* k has been defined
        m.class_eval do
            inherited_enumerable(:mapped, :map, :map => true) { Hash.new }
        end
        check_inherited_enumerable(m, k)
    end

    def test_inherited_enumerable_class
	a = Class.new do
	    inherited_enumerable(:signature, :signatures) { Array.new }
	    inherited_enumerable(:mapped, :map, :map => true) { Hash.new }
	end
	b = Class.new(a) do
	    include Module.new # include an empty module between a and b to check that the module
			       # is skipped transparently
	    inherited_enumerable(:child_attribute) { Array.new }
	end
	check_inherited_enumerable(a, b)
	
	# Test for singleton class support
	object = b.new
	assert(object.singleton_class.respond_to?(:signatures))
	object.singleton_class.signatures << :in_singleton
	assert_equal([:in_singleton], object.singleton_class.signatures)
        assert_equal([:in_singleton, :in_derived, :in_base], object.singleton_class.enum_for(:each_signature).to_a)
    end

    def check_inherited_enumerable(base, derived)
	assert(base.respond_to?(:each_signature))
	assert(base.respond_to?(:signatures))
	assert(!base.respond_to?(:has_signature?))
	assert(!base.respond_to?(:find_signatures))

	assert(base.respond_to?(:each_mapped))
	assert(base.respond_to?(:map))
	assert(base.respond_to?(:has_mapped?))

        base.signatures << :in_base
        base.map[:base] = 10
        base.map[:overriden] = 20
        assert_equal([:in_base], base.enum_for(:each_signature).to_a)
        assert_equal([10].to_set, base.enum_for(:each_mapped, :base, false).to_set)

	assert(!base.respond_to?(:child_attribute))
	assert(!base.respond_to?(:each_child_attribute))
	assert(derived.respond_to?(:child_attribute))
	assert(derived.respond_to?(:each_child_attribute))

        derived.signatures << :in_derived

        derived.map[:overriden] = 15
        derived.map[:derived] = 25

        assert_equal([:in_derived, :in_base], derived.enum_for(:each_signature).to_a)
        assert_equal([20, 15].to_set, derived.enum_for(:each_mapped, :overriden, false).to_set)
        assert_equal([15].to_set, derived.enum_for(:each_mapped, :overriden, true).to_set)
        assert_equal([25].to_set, derived.enum_for(:each_mapped, :derived).to_set)
        assert_equal([[:base, 10], [:overriden, 20], [:overriden, 15], [:derived, 25]].to_set, derived.enum_for(:each_mapped, nil, false).to_set)
        assert_equal([[:base, 10], [:overriden, 15], [:derived, 25]].to_set, derived.enum_for(:each_mapped, nil, true).to_set)
    end

    def test_has_ancestor
        mod       = Module.new
        parent    = Class.new do
            include mod
        end
        child     = Class.new(parent)
        singleton = child.new.singleton_class

        assert(child.has_ancestor?(parent))
        assert(child.has_ancestor?(mod))
        assert(parent.has_ancestor?(mod))

        assert(singleton.has_ancestor?(parent), singleton.superclass)
        assert(singleton.has_ancestor?(mod))
        assert(singleton.has_ancestor?(child))

        assert(!parent.has_ancestor?(child))
        assert(!parent.has_ancestor?(singleton))
    end
end

