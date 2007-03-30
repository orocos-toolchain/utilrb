require 'test_config'
require 'utilrb/exception'
require 'flexmock'

class TC_Exception < Test::Unit::TestCase
    def test_full_message
	FlexMock.use do |mock|
	    msg = begin
		      raise "this is an error"
		  rescue RuntimeError => error
		      error.full_message { |trace| trace !~ /test\/unit\// }
		  end

	    lines = msg.split("\n")
	    assert_equal(4, lines.size, lines)
	end
    end
end

