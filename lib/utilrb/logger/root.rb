require 'utilrb/logger/hierarchy'
class Logger
    HAS_COLOR =
        begin
            require 'highline'
            @console = HighLine.new
        rescue LoadError
        end

    LEVEL_TO_COLOR =
        { 'DEBUG' => [],
          'INFO' => [],
          'WARN' => [:magenta],
          'ERROR' => [:red],
          'FATAL' => [:red, :bold] }

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
    #       extend Logger.Root('MyModule', :WARN)
    #   end
    #
    #   MyModule.info "text"
    #   MyModule.warn "warntext"
    def self.Root(progname, base_level, &block)
        console = @console
        formatter =
            if block then lambda(&block)
            elsif HAS_COLOR
                lambda do |severity, time, progname, msg|
                    console.color("#{progname}[#{severity}]: #{msg}\n", *LEVEL_TO_COLOR[severity])
                end
            else lambda { |severity, time, progname, msg| "#{progname}[#{severity}]: #{msg}\n" }
            end

        Module.new do
            include Logger::Forward
            include Logger::HierarchyElement

            def has_own_logger?; true end

            define_method :logger do
                if logger = super()
                    return logger
                end

                logger = Logger.new(STDOUT)
                logger.level = base_level
                logger.progname = progname
                logger.formatter = formatter
                @default_logger = logger
            end
        end
    end
end

