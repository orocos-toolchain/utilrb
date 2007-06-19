require 'test_config'

require 'utilrb/objectstats'
require 'utilrb/hash/to_s'

class TC_ObjectStats < Test::Unit::TestCase
    def teardown
	GC.enable
    end

    def allocate_dead_hash; Hash.new; nil end

    def assert_profile(expected, value, string = nil)
	value = value.dup
	value.delete(ObjectStats::LIVE_OBJECTS_KEY)
	assert_equal(expected, value, (string || "") + " #{value}")
    end

    def test_object_stats
	assert_profile({}, ObjectStats.profile { ObjectStats.count }, "Object allocation profile changed")
	assert_profile({ Hash => 1 }, ObjectStats.profile { ObjectStats.count_by_class }, "Object allocation profile changed")
	assert_profile({ Array => 1 }, ObjectStats.profile { test = [] })
	assert_profile({ Array => 2, Hash => 1 }, ObjectStats.profile { a, b = [], {} })
    end
end

