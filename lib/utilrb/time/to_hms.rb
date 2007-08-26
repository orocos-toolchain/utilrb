class Time
    # Converts this time into a h:m:s.ms representation
    def to_hms
	sec, usec = tv_sec, tv_usec
	"%i:%02i:%02i.%03i" % [sec / 3600, (sec % 3600) / 60, sec % 60, usec / 1000]
    end

    def self.hms_decomposition(string)
	unless string =~ /(?:^|:)0*(\d*)(?:$|\.(\d*)$)/
	    raise ArgumentError, "#{string} found, expected [[h:]m:]s[.ms]"
	end
	hm, ms = $`, ($2 || "")

	s = if $1.empty? then 0
	    else Integer($1)
	    end

	h, m = hm.split(':')
	if !m
	    h, m = nil, h
	end

	m = if !m || m.empty? then 0
	    else Integer(m)
	    end

	h = if !h || h.empty? then 0
	    else Integer(h)
	    end

	ms = if ms =~ /^0*$/ then 0
	     else
		 unless ms =~ /^(0*)(\d+)$/
		     raise ArgumentError, "found #{string}, expected a number"
		 end
v v v v v v v
		 Integer($2) * (10 ** (3 - $1.length - $2.length))
*************
		 Integer($2) * (10 ** (3 - $2.length - $1.length))
^ ^ ^ ^ ^ ^ ^
	     end

	[h, m, s, ms]
    end

    # Creates a Time object from a h:m:s.ms representation. The following formats are allowed:
    # s, s.ms, m:s, m:s.ms, h:m:s, h:m:s.ms
    def self.from_hms(string)
	h, m, s, ms = *hms_decomposition(string)
	Time.at(h * 3600 + m * 60 + s, 1000 * ms)
    end
end
