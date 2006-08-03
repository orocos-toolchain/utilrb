require 'test/unit'
require 'test_config'
require 'enumerator'
require 'set'

require 'utilrb/hash'

class TC_Hash < Test::Unit::TestCase
    def test_slice
	test = { :a => 1, :b => 2, :c => 3 }
	assert_equal({:a => 1, :c => 3}, test.slice(:a, :c))
    end
end

