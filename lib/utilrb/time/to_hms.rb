class Time
    # Converts this time into a h:m:s.ms representation
    def to_hms
	sec, usec = tv_sec, tv_usec
	"%i:%02i:%02i.%03i" % [sec / 3600, (sec % 3600) / 60, sec % 60, usec / 1000]
    end

    # Creates a Time object from a h:m:s.ms representation. The following formats are allowed:
    # s, s.ms, m:s, m:s.ms, h:m:s, h:m:s.ms
    def self.from_hms(string)
	unless string =~ /(?:^|:)0*(\d*)(?:$|\.)/
	    raise ArgumentError, "#{string} found, expected [[h:]m:]s[.ms]"
	end
	hm, ms = $`, $'

	s = if $1.empty? then 0
	    else Integer($1)
	    end

	unless hm =~ /^(?:0*(\d*):)?(?:0*(\d*))?$/
	    raise ArgumentError, "found #{hm}, expected nothing, m: or h:m:"
	end

	h, m = if (!$1 || $1.empty?) && $2.empty? then [0, 0]
	       elsif (!$1 || $1.empty?) then [0, Integer($2)]
	       elsif $2.empty? then [0, Integer($1)]
	       else
		   [Integer($1), Integer($2)]
	       end

	ms = if ms =~ /^0*$/ then 0
	     else
		 unless ms =~ /^(0*)(\d+)$/
		     raise ArgumentError, "found #{string}, expected a number"
		 end
		 Integer($2) * (10 ** (3 - $1.length - $2.length))
	     end

	Time.at(Float(h * 3600 + m * 60 + s) + ms * 1.0e-3)
    end
end
