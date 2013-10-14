require './test/test_config'

class TC_Misc < Test::Unit::TestCase
    def test_super_idiom
	base = Class.new do
	    attr_reader :base
	    def initialize
		super if defined? super
		@base = true
	    end
	end
	assert_nothing_raised { base.new }

	derived = Class.new(base) do
	    attr_reader :derived
	    def initialize
		super if defined? super
		@derived = true
	    end
	end
	obj = nil
	assert_nothing_raised { obj = derived.new }
	assert( obj.base )
	assert( obj.derived )

	mod = Module.new do
	    attr_reader :module
	    def initialize
		super if defined? super
		@module = true
	    end
	end
	obj = nil
	base.class_eval { include mod }

	assert_nothing_raised { obj = derived.new }
	assert( obj.base )
	assert( obj.module )
	assert( obj.derived )
    end
end

