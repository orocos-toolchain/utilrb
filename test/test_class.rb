require 'test/unit'
require 'test_config'
require 'enumerator'
require 'set'

require 'utilrb/class'

class TC_Class < Test::Unit::TestCase
    def test_singleton_class
	klass	= Class.new
	object	= klass.new
	assert_equal(object, object.singleton_class.singleton_instance)
    end

    def test_superclass_call
	base    = Class.new do
	    class << self
		attr_accessor :attribute
		def read_attribute
		    [attribute, superclass_call(:read_attribute)]
		end
	    end
	end
	derived = Class.new(base)
	object  = derived.new

	base.attribute	    = 10
	derived.attribute   = 20
	object.singleton_class.attribute = 30
	assert_equal([30, [20, [10, nil]]], object.singleton_class.read_attribute)
    end

    def test_inherited_enumerable
	a = Class.new do
	    class_inherited_enumerable(:signature, :signatures) { Array.new }
	    class_inherited_enumerable(:mapped, :map, :map => true) { Hash.new }
	end
	b = Class.new(a) do
	    class_inherited_enumerable(:only_in_child) { Hash.new }
	end

        [a, b].each do |klass|
            assert(klass.respond_to?(:each_signature))
            assert(klass.respond_to?(:signatures))
            assert(!klass.respond_to?(:has_signature?))
            assert(!klass.respond_to?(:find_signatures))

            assert(klass.respond_to?(:each_mapped))
            assert(klass.respond_to?(:map))
            assert(klass.respond_to?(:has_mapped?))
        end

	assert(!a.respond_to?(:only_in_child))
	assert(!a.respond_to?(:each_only_in_child))
	assert(b.respond_to?(:only_in_child))
	assert(b.respond_to?(:each_only_in_child))

        a.signatures << :in_a
        b.signatures << :in_b

        a.map[:a] = 10
        a.map[:b] = 20
        b.map[:a] = 15
        b.map[:c] = 25

        assert_equal([:in_a], a.enum_for(:each_signature).to_a)
        assert_equal([:in_b, :in_a], b.enum_for(:each_signature).to_a)
        assert_equal([10, 15].to_set, b.enum_for(:each_mapped, :a, false).to_set)
        assert_equal([15].to_set, b.enum_for(:each_mapped, :a, true).to_set)
        assert_equal([10].to_set, a.enum_for(:each_mapped, :a, false).to_set)
        assert_equal([20].to_set, b.enum_for(:each_mapped, :b).to_set)
        assert_equal([[:a, 10], [:b, 20], [:a, 15], [:c, 25]].to_set, b.enum_for(:each_mapped, nil, false).to_set)
        assert_equal([[:a, 15], [:b, 20], [:c, 25]].to_set, b.enum_for(:each_mapped, nil, true).to_set)

	# Test for singleton class support
	object = b.new
	assert(object.singleton_class.respond_to?(:signatures))
	object.singleton_class.signatures << :in_singleton
	assert_equal([:in_singleton], object.singleton_class.signatures)
        assert_equal([:in_singleton, :in_b, :in_a], object.singleton_class.enum_for(:each_signature).to_a)
    end

end

