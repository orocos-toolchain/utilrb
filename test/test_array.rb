require 'utilrb/array'

class TC_Array < Test::Unit::TestCase
    def test_to_s
	assert_equal("1, 2", [1, 2].to_s)
    end
end

