require 'test_config'

require 'utilrb/gc'
require 'enumerator'

class TC_GC < Test::Unit::TestCase
    def allocate(&block)
	ObjectSpace.define_finalizer(Object.new, &block)
	nil
    end

    def allocate(&block)
	# Allocate twice since it seems the last object stays on stack
	# (and is not GC'ed)
	2.times { ObjectSpace.define_finalizer(Object.new, &block) }
	nil
    end

    def test_force
	finalized = false
	allocate { finalized = true }
	GC.start
	assert( finalized )

	GC.disable
	finalized = false
	allocate { finalized = true }
	GC.start
	assert( !finalized )
	GC.force
	assert( finalized )
	assert( GC.disable )

	GC.enable
	GC.force
	assert( !GC.enable )
    end
end

