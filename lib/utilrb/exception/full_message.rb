
class Exception
    # Returns the full exception message, with backtrace, like the one we get from
    # the Ruby interpreter when the program is aborted (well, almost like that)
    #
    # For instance,
    #	def test
    #	    raise RuntimeError, "this is a test"
    #	rescue 
    #	    puts $!.full_message
    #	end
    #	test
    #
    # displays
    #
    #   test.rb:3:in `test': this is a test (RuntimeError)
    #         from test.rb:7
    #
    def full_message
	first, *remaining = backtrace
	"#{first}: #{message} (#{self.class})\n\tfrom " + remaining.join("\n\tfrom ")
    end
end

