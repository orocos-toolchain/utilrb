module GC
    # Forcefully starts the GC even when GC.disable has been called
    def self.force
	already_enabled = !GC.enable
	GC.start
    ensure
	GC.disable unless already_enabled
    end
end


