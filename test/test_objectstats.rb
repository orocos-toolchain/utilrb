require 'test_config'

require 'utilrb/objectstats'

class TC_ObjectStats < Test::Unit::TestCase
    def test_object_stats
	assert( ObjectStats.profile { ObjectStats.count }.empty?, "Object allocation profile changed" )
	assert_equal({ Hash => 1 }, ObjectStats.profile { ObjectStats.count_by_class }, "Object allocation profile changed")
	assert_equal({ Array => 1 }, ObjectStats.profile { test = [] })
	assert_equal({ Array => 2, Hash => 1 }, ObjectStats.profile { a, b = [], {} })

	GC.start
        GC.disable
        Hash.new
        assert([Hash, 1], ObjectStats.profile { Hash.new }.collect { |klass, count| [klass, count] })
        assert([Hash, -1], ObjectStats.profile { GC.start }.collect { |klass, count| [klass, count] })
    end
end

