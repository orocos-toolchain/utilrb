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
	obj = { 1 => 2, 2 => 3 }
	assert(obj.to_s =~ /^\{(.*)\}$/)
	values = $1.split(", ")
	assert_equal(["1 => 2", "2 => 3"].to_set, values.to_set)

	obj[3] = obj
	assert(obj.to_s =~ /^\{(.*)\}$/)
	values = $1.split(", ")
	assert_equal(["1 => 2", "2 => 3", "3 => ..."].to_set, values.to_set)
    end

    def test_map_key
        base = { 1 => 'a', 2 => 'b' }
        result = base.map_key { |k, v| k += 1 }

        assert_equal({ 1 => 'a', 2 => 'b' }, base)
        assert_equal({ 2 => 'a', 3 => 'b' }, result)
    end

    def test_map_value
        base = { 'a' => 1, 'b' => 2 }
        result = base.map_value { |k, v| v += 1 }

        assert_equal({ 'a' => 1, 'b' => 2 }, base)
        assert_equal({ 'a' => 2, 'b' => 3 }, result)
    end

    def test_recursive_merge
        base = { 'a' => 1, 'b' => { 'c' => 10, 'd' => 20 }, 'c' => 2 }
        base_orig = base.dup
        to_merge = { 'a' => 10, 'b' => { 'c' => 100 }, 'd' => 3 }
        to_merge_orig = to_merge.dup
        result = base.recursive_merge(to_merge)

        assert_equal(base, base_orig)
        assert_equal(to_merge, to_merge_orig)
        assert_equal({'a' => 10, 'b' => { 'c' => 100, 'd' => 20 }, 'c' => 2, 'd' => 3}, result)
    end

    def test_recursive_merge_with_block
        base = { 'a' => 1, 'b' => { 'c' => 10, 'd' => 20 }, 'c' => 2 }
        base_orig = base.dup
        to_merge = { 'a' => 10, 'b' => { 'c' => 100 }, 'd' => 3 }
        to_merge_orig = to_merge.dup
        args = []
        result = base.recursive_merge(to_merge) do |v, k1, k2|
            args << [v, k1, k2]
            k1
        end

        assert_equal(base, base_orig)
        assert_equal(to_merge, to_merge_orig)
        assert_equal([['a', 1, 10], ['c', 10, 100]].to_set, args.to_set)
        assert_equal({'a' => 1, 'b' => { 'c' => 10, 'd' => 20 }, 'c' => 2, 'd' => 3}, result)
    end

    def test_recursive_merge_bang
        base = { 'a' => 1, 'b' => { 'c' => 10, 'd' => 20 }, 'c' => 2 }
        to_merge = { 'a' => 10, 'b' => { 'c' => 100 }, 'd' => 3 }
        to_merge_orig = to_merge.dup
        result = base.recursive_merge!(to_merge)

        assert_equal(result, base)
        assert_equal(to_merge, to_merge_orig)
        assert_equal({'a' => 10, 'b' => { 'c' => 100, 'd' => 20 }, 'c' => 2, 'd' => 3}, result)
    end

    def test_recursive_merge_bang_with_block
        base = { 'a' => 1, 'b' => { 'c' => 10, 'd' => 20 }, 'c' => 2 }
        to_merge = { 'a' => 10, 'b' => { 'c' => 100 }, 'd' => 3 }
        to_merge_orig = to_merge.dup
        args = []
        result = base.recursive_merge!(to_merge) do |v, k1, k2|
            args << [v, k1, k2]
            k1
        end

        assert_equal(result, base)
        assert_equal(to_merge, to_merge_orig)
        assert_equal([['a', 1, 10], ['c', 10, 100]].to_set, args.to_set)
        assert_equal({'a' => 1, 'b' => { 'c' => 10, 'd' => 20 }, 'c' => 2, 'd' => 3}, result)
    end
end

