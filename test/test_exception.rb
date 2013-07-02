require 'test/test_config'
require 'utilrb/exception'
require 'flexmock'

class TC_Exception < Test::Unit::TestCase
    def test_full_message
	FlexMock.use do |mock|
	    error = Exception.new
	    def error.message; "this is an error" end
	    def error.backtrace
		(0..10).map { |i| i.to_s }
	    end

	    full     = error.full_message.split("\n")
	    assert_equal(11, full.size)

	    filtered = error.full_message { |line| Integer(line) % 2 == 0 }.split("\n")
	    assert_equal(6, filtered.size)
	    assert_equal(full.values_at(0, 2, 4, 6, 8, 10), filtered)

	    since_matches = error.full_message(:since => /4/).split("\n")
	    assert_equal(7, since_matches.size)
	    assert_equal(full.values_at(*(5..10)), since_matches[1..-1])

	    until_matches = error.full_message(:until => /3/).split("\n")
	    assert_equal(3, until_matches.size)
	    assert_equal(full.values_at(1, 2), until_matches[1..-1])

	    since_and_until = error.full_message(:since => /3/, :until => /6/).split("\n")
	    assert_equal(3, since_and_until.size)
	    assert_equal(full.values_at(4, 5), since_and_until[1..-1])

	    all = error.full_message(:since => /3/, :until => /6/) { |line| Integer(line) % 2 == 0 }.split("\n")
	    assert_equal(1, all.size)
	end
    end
end

