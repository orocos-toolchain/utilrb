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

module Kernel
    def unless_faster
	return yield unless UTILRB_FASTER_MODE
    end
    def require_faster(name)
	if UTILRB_FASTER_MODE
	    yield
	else
	    STDERR.puts "Utilrb: not loading #{name} since the C extension is not available"
	end
    end
end

