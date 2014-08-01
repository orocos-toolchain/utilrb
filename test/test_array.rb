require 'utilrb/test'
require 'utilrb/array'

class TC_Array < Minitest::Test
    def test_to_s
	assert_equal("[1, 2]", [1, 2].to_s)
    end
    def test_to_s_recursive
	obj = [1, 2]
	obj << obj
	assert_equal("[1, 2, ...]", obj.to_s)
    end

end

