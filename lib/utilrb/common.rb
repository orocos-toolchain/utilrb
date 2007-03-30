module Utilrb
    VERSION = "1.0" unless defined? Utilrb::VERSION

    unless defined? UTILRB_FASTER_MODE
	if ENV['UTILRB_FASTER_MODE'] == 'no'
	    UTILRB_FASTER_MODE = nil
	    STDERR.puts "Utilrb: not loading the C extension"
	else
	    begin
		require 'utilrb/faster'
		UTILRB_FASTER_MODE = true
		STDERR.puts "Utilrb: loaded C extension" if ENV['UTILRB_FASTER_MODE']
	    rescue LoadError => e
		raise unless e.message =~ /no such file to load/
		if ENV['UTILRB_FASTER_MODE'] == 'yes'
		    raise LoadError, "unable to load Util.rb C extension: #{e.message}"
		else
		    UTILRB_FASTER_MODE = nil
		end
	    end
	end
    end

    # Yields if the faster extension is not present
    # This is used by Utilrb libraries to provide a 
    # Ruby version if the C extension is not loaded
    def self.unless_faster # :yield:
	unless UTILRB_FASTER_MODE
	    return yield if block_given?
	end
    end

    # Yields if the faster extension is present. This is used for Ruby code
    # which depends on methods in the C extension
    def self.if_faster(&block)
	require_faster(nil, &block)
    end

    # Yields if the faster extension is present, and 
    # issue a warning otherwise. This is used for Ruby
    # code which depends on methods in the C extension
    def self.require_faster(name)
	if UTILRB_FASTER_MODE
	    yield if block_given?
	elsif name
	    STDERR.puts "Utilrb: not loading #{name} since the C extension is not available"
	end
    end
end

