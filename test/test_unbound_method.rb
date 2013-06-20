require 'test/test_config'
require 'utilrb/unbound_method'
require 'flexmock'

class TC_UnboundMethod < Test::Unit::TestCase
    def test_call
	FlexMock.use do |mock|
	    klass = Class.new do
		define_method(:mock) { mock }
		def tag(value, &block)
		    mock.method_called(value)
		    block.call(value)
		end
	    end
	    obj = klass.new

	    mock.should_receive(:method_called).with(42).once
	    mock.should_receive(:block_called).with(42).once
	    klass.instance_method(:tag).call(obj, 42) { |value| mock.block_called(value) }
	end
    end
end

