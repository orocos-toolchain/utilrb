require 'utilrb/test'

require 'utilrb/object'
require 'utilrb/module/attr_predicate'

class TC_Object < Minitest::Test
    def test_address
	assert_equal("2aaaab38b398", Object.address_from_id(0x1555559c59cc).to_s(16))

	foo = Object.new
	foo.to_s =~ /#<Object:0x0*([0-9a-f]+)>/
	foo_address = $1
	assert_equal(foo_address, foo.address.to_s(16), "#{foo} #{foo.address.to_s(16)} #{foo.object_id.to_s(16)}")
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
	refute_same(obj1.as_hash, obj2.as_hash)

	refute_same(obj1.block, obj2.block)
	obj1.block = obj2.block
	assert_same(obj1.block, obj2.block)
    end

    def test_attr_predicate
	klass = Class.new do
	    attr_predicate :working
	    attr_predicate :not_working, true
	end
	assert(klass.method_defined?(:working?))
	assert(!klass.method_defined?(:working))
	assert(!klass.method_defined?(:working=))
	assert(klass.method_defined?(:not_working?))
	assert(!klass.method_defined?(:not_working))
	assert(klass.method_defined?(:not_working=))

	object = klass.new
	object.instance_eval { @working = true }
	assert(object.working?)
	object.not_working = 5
	assert_equal(true, object.not_working?)
    end
end

