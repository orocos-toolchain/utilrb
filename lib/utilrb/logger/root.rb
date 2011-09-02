class Logger
    def self.Root(progname, base_level, &block)
        formatter =
            if block then lambda(&block)
            else lambda { |severity, time, progname, msg| "#{progname}: #{msg}\n" }
            end

        Module.new do
            include Logger::Forward

            singleton = (class << self; self end)
            singleton.send(:define_method, :extended) do |mod|
                logger = Logger.new(STDOUT)
                logger.level = base_level
                logger.progname = progname
                logger.formatter = formatter
                mod.instance_variable_set(:@logger, logger)
            end

            attr_reader :logger
        end
    end
end

