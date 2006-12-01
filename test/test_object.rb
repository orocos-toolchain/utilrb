require 'test_config'

require 'utilrb/object'

class TC_Object < Test::Unit::TestCase
    def test_address
	foo = Object.new
	foo.to_s =~ /#<Object:0x([0-9a-f]+)>/
	foo_address = $1
	assert_equal(foo_address, foo.address.to_s(16), "#{foo} #{foo.address} #{foo.object_id}")
    end

    def check_attribute(object)
	assert(object.respond_to?(:as_hash))
	assert(object.respond_to?(:as_hash=))
	assert(object.respond_to?(:block))
	assert(object.respond_to?(:block=))
	hash_attribute = object.as_hash
	block_attribute = object.block
	assert(Hash === hash_attribute)
	assert(Array === block_attribute)

	new_value = Time.now

	assert_same(hash_attribute, object.as_hash)
	object.as_hash = new_value
	assert_same(new_value, object.as_hash)

	assert_same(block_attribute, object.block)
	object.block = new_value
	assert_same(object.block, new_value)
    end
    def test_attribute
	klass = Class.new do
	    attribute :as_hash => Hash.new
	    attribute(:block) { Array.new }
	    class_attribute :as_hash => Hash.new # do NOT use :hash here as it would override #hash which is a quite useful method ...
	    class_attribute(:block) { Array.new }
	end

	obj1, obj2 = klass.new, klass.new
	check_attribute(obj1)
	check_attribute(obj2)

	obj1, obj2 = klass.new, klass.new
	assert_same(obj1.as_hash, obj2.as_hash)
	obj1.as_hash = Hash.new
	assert_not_same(obj1.as_hash, obj2.as_hash)

	assert_not_same(obj1.block, obj2.block)
	obj1.block = obj2.block
	assert_same(obj1.block, obj2.block)
    end

    def test_singleton_class
	klass	= Class.new
	object	= klass.new
	assert(! object.has_singleton?)
	assert_equal(object, object.singleton_class.singleton_instance)
	assert(object.has_singleton?)
	assert_equal(klass, object.singleton_class.superclass)
	assert_equal([object.singleton_class, klass, Object], object.singleton_class.ancestors[0, 3])
    end
end

