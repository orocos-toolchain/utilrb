require 'utilrb/kernel/options'

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
    # Two regular expressions can be given through the +options+ hash to filter the backtrace:
    # since:: 
    #   Only the methods *below* the first matching line will be displayed. The matching
    #   line is included.
    # until::
    #   Only the methods *above* the first matching line will be displayed. The matching
    #   line is *not* included
    #
    # If a block is given, each line of the backtrace are yield and only the lines for which
    # the block returns true are displayed
    #
    def full_message(options = {}, &block)
	options = validate_options options, [:since, :until]
	since_matches, until_matches = options[:since], options[:until]

	trace = backtrace
	if since_matches || until_matches
	    found_beginning, found_end = !since_matches, false
	    trace = trace.find_all do |line|
		found_beginning ||= (line =~ since_matches)
		found_end       ||= (line =~ until_matches) if until_matches
		found_beginning && !found_end
	    end
	end

	first, *remaining = if block_given? then trace.find_all(&block)
			    else trace
			    end

	msg = "#{first}: #{message} (#{self.class})"
	unless remaining.empty?
	    msg << "\n\tfrom " + remaining.join("\n\tfrom ")
	end
	msg
    end
end

