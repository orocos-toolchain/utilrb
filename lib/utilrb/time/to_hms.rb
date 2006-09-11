class Time
    def to_hms
	sec, usec = tv_sec, tv_usec
	"%i:%02i:%02i.%03i" % [sec / 3600, (sec % 3600) / 60, sec % 60, usec / 1000]
    end
end
