
# Utilrb is yet another Ruby toolkit, in the spirit of facets. It includes all
# the standard class extensions used by www.rock-robotics.org projects.
module Utilrb
    unless defined? Utilrb::VERSION
	VERSION = "1.6.6"
        RUBY_IS_19  = (RUBY_VERSION >= "1.9.2")
        RUBY_IS_191 = (RUBY_VERSION >= "1.9") && (RUBY_VERSION < "1.9.2")
    end

    unless defined? UTILRB_EXT_MODE
	if ENV['UTILRB_EXT_MODE'] == 'no'
	    UTILRB_EXT_MODE = nil
	    STDERR.puts "Utilrb: not loading the C extension"
	else
	    begin
		require 'utilrb/utilrb'
		UTILRB_EXT_MODE = true
		STDERR.puts "Utilrb: loaded C extension" if ENV['UTILRB_EXT_MODE']
	    rescue LoadError => e
		if ENV['UTILRB_EXT_MODE'] == 'yes'
		    raise LoadError, "unable to load Util.rb C extension: #{e.message}"
		else
		    UTILRB_EXT_MODE = nil
		end
	    end
	end
    end

    # Yields if the extension is not present
    # This is used by Utilrb libraries to provide a 
    # Ruby version if the C extension is not loaded
    def self.unless_ext # :yield:
	unless UTILRB_EXT_MODE
	    return yield if block_given?
	end
    end

    # Yields if the extension is present. This is used for Ruby code
    # which depends on methods in the C extension
    def self.if_ext(&block)
	require_ext(nil, &block)
    end

    # Yields if the extension is present, and 
    # issue a warning otherwise. This is used for Ruby
    # code which depends on methods in the C extension
    def self.require_ext(name)
	if UTILRB_EXT_MODE
	    yield if block_given?
	elsif name
	    STDERR.puts "Utilrb: not loading #{name} since the C extension is not available"
	end
    end
end

