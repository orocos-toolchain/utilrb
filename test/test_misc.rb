require 'utilrb/test'

class TC_Misc < Minitest::Test
    def test_super_idiom
	base = Class.new do
	    attr_reader :base
	    def initialize
		super if defined? super
		@base = true
	    end
	end
        # Should not raise
	base.new

	derived = Class.new(base) do
	    attr_reader :derived
	    def initialize
		super if defined? super
		@derived = true
	    end
	end
	obj = nil
        # Should not raise
	obj = derived.new
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

        # Should not raise
	obj = derived.new
	assert( obj.base )
	assert( obj.module )
	assert( obj.derived )
    end
end

