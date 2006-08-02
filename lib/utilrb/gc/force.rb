module GC
    # Forcefully starts the GC even when GC.disable has been called
    def self.force
	enabled_gc = GC.enable
	GC.start
    ensure
	GC.disable unless enabled_gc
    end
end


