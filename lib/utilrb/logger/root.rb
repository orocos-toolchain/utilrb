class Logger
    # Defines a logger on a module, allowing to use that module as a root in a
    # hierarchy (i.e. having submodules use the Logger::Hierarchy support)
    #
    # +progname+ is used as the logger's program name
    #
    # +base_level+ is the level at which the logger is initialized
    #
    # If a block is given, it will be provided the message severity, time,
    # program name and text and should return the formatted message.
    #
    # This method creates a +logger+ attribute in which the module can be
    # accessed. Moreover, it includes Logger::Forward, which allows to access
    # the logger's output methods on the module directly
    #
    # Example:
    #
    #   module MyModule
    #       include Logger.Root('MyModule', :WARN)
    #   end
    #
    #   MyModule.info "text"
    #   MyModule.warn "warntext"
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

            attr_accessor :logger
        end
    end
end

