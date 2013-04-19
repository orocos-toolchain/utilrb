class Logger
    # Silences this logger for the duration of the block
    def silent
        current_level, self.level = self.level, Logger::FATAL + 1
        yield
    ensure
        self.level = current_level
    end
end

