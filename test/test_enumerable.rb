require 'test/unit'
require 'test_config'

require 'utilrb/enumerable'

class TC_Enumerable < Test::Unit::TestCase

    def test_enum_uniq
        # Test the enum_uniq enumerator
        assert_equal([:a, :b, :c], [:a, :b, :a, :c].enum_uniq { |k| k }.to_a)
        assert_equal([:a, :b, :c], [:a, :b, :a, :c].enum_uniq.to_a)
        assert_equal([:a, :b, :c], [:a, :b, :a, :c].enum_for(:each_uniq).to_a)
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

    def test_enum_sequence
	c1 = [:a, :b, :c]
	c2 = [:d, :e, :f]
	assert_equal([:a, :b, :c, :d, :e, :f], (c1.to_enum + c2.to_enum).to_a)
	assert_equal([:a, :b, :c, :d, :e, :f], [c1, c2].inject(null_enum) { |a, b| a + b }.to_a)
    end

end

