require 'test_config'

require 'utilrb/enumerable'
require 'utilrb/value_set'

class TC_Enumerable < Test::Unit::TestCase

    def test_enum_uniq
        # Test the enum_uniq enumerator
        assert_equal([:a, :b, :c], [:a, :b, :a, :c].enum_uniq { |k| k }.to_a)
        assert_equal([:a, :b, :c], [:a, :b, :a, :c].enum_uniq.to_a)
	enum = [:a, :b, :a, :c].enum_uniq
	assert_equal(enum, enum.each)
	
        a, b, c, d = [1, 2], [1, 3], [2, 3], [3, 4]

        test = [a, b, c, d]
        assert_equal([a, c, d], test.enum_uniq { |x, y| x }.to_a)
        assert_equal([a, b, d], test.enum_uniq { |x, y| y }.to_a)

	klass = Class.new do
	    def initialize(base); @base = base end
	    def each(&iterator);  @base.each { |x, y| yield [x, y] } end
	    include Enumerable
	end
	test = klass.new(test)
        assert_equal([a, c, d], test.enum_uniq { |x, y| x }.to_a)
        assert_equal([a, b, d], test.enum_uniq { |x, y| y }.to_a)

        klass = Struct.new :x, :y
	test = test.map { |x, y| klass.new(x, y) }
        a, b, c, d = *test
        assert_equal([a, c, d], [a, b, c, d].enum_uniq { |v| v.x }.to_a)
        assert_equal([a, b, d], [a, b, c, d].enum_uniq { |v| v.y }.to_a)
    end
    
    def test_each_uniq
        assert_equal([:a, :b, :c], [:a, :b, :a, :c].enum_for(:each_uniq).to_a)
    end

    def test_enum_sequence
	c1 = [:a, :b, :c]
	c2 = [:d, :e, :f]
	assert_equal([:a, :b, :c, :d, :e, :f], (c1.to_enum + c2.to_enum).to_a)
	assert_equal([:a, :b, :c, :d, :e, :f], [c1, c2].inject(null_enum) { |a, b| a + b }.to_a)
	assert_equal([:a, :b, :c, :d, :e, :f], [c1, c2].inject(SequenceEnumerator.new) { |a, b| a << b }.to_a)
    end

    def test_random_element
	# Test on arrays
	set = (1..100).to_a
	100.times { set.delete(set.random_element) }
	assert(set.empty?)
	assert_equal(nil, [].random_element)

	# Test on non-empty collection which defines #size
	set = Hash[*(1..100).map { |i| [(?a + i).to_s, i] }.flatten]
	100.times { set.delete(set.random_element.first) }
	assert(set.empty?)
	assert_equal(nil, {}.random_element)
    end

    Utilrb.require_faster('test_value_set') do
	def test_value_set
	    a = [1, 3, 3, 4, 6, 8].to_value_set
	    b = [1, 2, 4, 3, 11, 11].to_value_set
	    assert_equal(5, a.size)
	    assert_equal([1, 3, 4, 6, 8], a.to_a)
	    assert(a.include?(1))
	    assert(a.include_all?([4, 1, 8]))
	    assert(!a.include_all?(b))

	    assert(a.object_id == a.to_value_set.object_id)

	    assert_equal([1, 2, 3, 4, 6, 8, 11], (a.union(b)).to_a)
	    assert_equal([1, 3, 4], (a.intersection(b)).to_a)
	    assert_equal([6, 8], (a.difference(b)).to_a)
	    assert(! (a == :bla)) # check #== behaves correctly with a non-enumerable

	    a.delete(1)
	    assert(! a.include?(1))
	    a.merge(b);
	    assert_equal([1, 2, 3, 4, 6, 8, 11].to_value_set, a)

	    assert([].to_value_set.empty?)

	    assert([1, 2, 4, 3].to_value_set.clear.empty?)

	    assert_equal([1,3,5].to_value_set, [1, 2, 3, 4, 5, 6].to_value_set.delete_if { |v| v % 2 == 0 })
	end
    end
end

