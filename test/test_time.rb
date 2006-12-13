require 'test_config'
require 'utilrb/time'

class TC_Time < Test::Unit::TestCase
    def test_to_hms
	assert_equal("0:00:00.000", Time.at(0).to_hms)
	assert_equal("0:00:00.100", Time.at(0.1).to_hms)
	assert_equal("0:00:34.100", Time.at(34.1).to_hms)
	assert_equal("0:21:34.100", Time.at(21 * 60 + 34.1).to_hms)
	assert_equal("236:21:34.100", Time.at(236 * 3600 + 21 * 60 + 34.1).to_hms)
    end
    def test_from_hms
	assert_equal(Time.at(0), Time.from_hms("0:00:00.000"))
	assert_equal(Time.at(0.1), Time.from_hms("0:00:00.100"))
	assert_equal(Time.at(34.1), Time.from_hms("0:00:34.100"))
	assert_equal(Time.at(21 * 60 + 34.1), Time.from_hms("0:21:34.100"))
	assert_equal(Time.at(236 * 3600 + 21 * 60 + 34.1), Time.from_hms("236:21:34.100"))

	assert_equal(Time.at(0), Time.from_hms("0"))
	assert_equal(Time.at(0), Time.from_hms(":0"))
	assert_equal(Time.at(62), Time.from_hms("1:2"))
	assert_equal(Time.at(3723), Time.from_hms("1:2:3"))

	assert_equal(Time.at(0), Time.from_hms("0"))
	assert_equal(Time.at(0), Time.from_hms("0."))
	assert_in_delta(0, Time.at(1.2) - Time.from_hms("1.2"), 0.001)
	assert_in_delta(0, Time.at(121.3) - Time.from_hms("2:1.3"), 0.001)
	assert_in_delta(0, Time.at(3723.4) - Time.from_hms("1:2:3.4"), 0.001)
    end
end

