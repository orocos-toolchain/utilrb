require 'test/unit'
require 'test_config'

require 'flexmock'
require 'set'
require 'enumerator'
require 'utilrb/module'

class TC_Module < Test::Unit::TestCase
    def test_define_method_with_block
	FlexMock.use do |mock|
	    mock.should_receive(:called).once
	    block_obj = lambda { mock.called }
	    test_obj = self
	    method = lambda do |a, b, block|
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
end

