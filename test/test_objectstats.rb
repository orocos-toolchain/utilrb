require 'test_config'

require 'utilrb/objectstats'

class TC_ObjectStats < Test::Unit::TestCase
    def teardown
	GC.enable
    end

    def allocate_dead_hash; Hash.new; nil end

    def test_object_stats
	assert( ObjectStats.profile { ObjectStats.count }.empty?, "Object allocation profile changed" )
	assert_equal({ Hash => 1 }, ObjectStats.profile { ObjectStats.count_by_class }, "Object allocation profile changed")
	assert_equal({ Array => 1 }, ObjectStats.profile { test = [] })
	assert_equal({ Array => 2, Hash => 1 }, ObjectStats.profile { a, b = [], {} })
    end
end

