class Time
    def to_hms
	sec, usec = tv_sec, tv_usec
	"%i:%02i:%02i.%03i" % [sec / 3600, (sec % 3600) / 60, sec % 60, usec / 1000]
    end
    #
    # :: => 0:0:
    # value => seconds
    def self.from_hms(string)
	unless string =~ /(?:^|:)(\d+)(?:$|\.)/
	    raise "invalid format "#{string}"
	end
	hm, ms = $`, $'

	s = Integer($1)
	unless hm =~ /^(?:(\d*):)?(?:(\d*))?$/
	    raise "invalid format #{string}. found #{hm}, expected nothing, m: or h:m:"
	end
	h, m = if $2.empty? then 
		   if $1 then [0, Integer($1)]
		   else [0, 0]
		   end
	       else [Integer($1), Integer($2)]
	       end

	ms = if ms.empty? then 0
	     else
		 unless ms =~ /^\d*$/
		     raise "invalid format "#{string}"
		 end
		 ms += "0" * (3 - ms.size)
		 Integer(ms)
	     end

	Time.at(Float(h * 3600 + m * 60 + s) + ms * 1.0e-3)
    end
end
