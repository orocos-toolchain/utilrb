require 'test/unit'
require 'test_config'
require 'enumerator'
require 'set'

require 'utilrb/hash'

class TC_Hash < Test::Unit::TestCase
    def test_slice
	test = { :a => 1, :b => 2, :c => 3 }
	assert_equal({:a => 1, :c => 3}, test.slice(:a, :c))
	assert_equal({:a => 1, :c => 3}, test.slice(:a, :c, :d))
    end

    def test_to_sym_keys
	assert_equal({ :a => 10, :b => 20, :c => 30 }, { 'a' => 10, 'b' => 20, :c => 30 }.to_sym_keys)
    end

    def test_to_s
	assert_equal("1 => 2, 2 => 3", { 1 => 2, 2 => 3 }.to_s)
    end
end

