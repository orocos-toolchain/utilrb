module GC
    # Forcefully starts the GC even when GC.disable has been called
    def self.force
	disabled_gc = GC.enable
	GC.start
    ensure
	GC.disable if disabled_gc
    end
end


