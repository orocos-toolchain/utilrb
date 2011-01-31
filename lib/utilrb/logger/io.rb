class Logger
    # An IO-like interface for a logger object
    class LoggerIO
        attr_reader :logger
        attr_reader :level

        def initialize(logger, level)
            @logger, @level = logger, level
            @buffer = ''
        end
        def puts(msg)
            print msg
            logger.send(level, @buffer)
            @buffer.clear
        end
        def print(msg)
            @buffer << msg
        end
    end

    def io(level)
        LoggerIO.new(self, level)
    end
end

