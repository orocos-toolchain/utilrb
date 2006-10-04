require 'test/unit'
require 'test_config'

require 'utilrb/kernel/options'
require 'utilrb/kernel/arity'
require 'utilrb/kernel/replace'

class TC_Kernel < Test::Unit::TestCase
    def test_validate_options
        valid_options   = [ :a, :b, :c ]
        valid_test      = { :a => 1, :c => 2 }
        invalid_test    = { :k => nil }
        assert_nothing_raised(ArgumentError) { validate_options(valid_test, valid_options) }
        assert_raise(ArgumentError) { validate_options(invalid_test, valid_options) }

        check_array = validate_options( valid_test, valid_options )
        assert_equal( valid_test, check_array )
        check_empty_array = validate_options( nil, valid_options )
        assert_equal( {}, check_empty_array )

	# Check default value settings
        default_values = { :a => nil, :b => nil, :c => nil, :d => 15, :e => [] }
        new_options = nil
        assert_nothing_raised(ArgumentError) { new_options = validate_options(valid_test, default_values) }
	assert_equal(15, new_options[:d])
	assert_equal([], new_options[:e])
        assert( !new_options.has_key?(:b) )
    end

    def test_arity
	object = Class.new do
	    def arity_1(a); end
	    def arity_any(*a); end
	    def arity_1_more(a, *b); end
	end.new

	assert_nothing_raised { check_arity(object.method(:arity_1), 1) }
	assert_raises(ArgumentError) { check_arity(object.method(:arity_1), 0) }
	assert_raises(ArgumentError) { check_arity(object.method(:arity_1), 2) }

	assert_nothing_raised { check_arity(object.method(:arity_any), 0) }
	assert_nothing_raised { check_arity(object.method(:arity_any), 2) }

	assert_nothing_raised { check_arity(object.method(:arity_1_more), 1) }
	assert_raises(ArgumentError) { check_arity(object.method(:arity_1_more), 0) }
	assert_nothing_raised { check_arity(object.method(:arity_1_more), 2) }
    end

    Utilrb.require_faster('test_replace') do
	def test_replace
	    obj = Array.new
	    myobj = Object.new
	    obj << myobj

	    Kernel.replace!(obj, Hash)
	    assert_instance_of Hash, obj
	end
    end
end

