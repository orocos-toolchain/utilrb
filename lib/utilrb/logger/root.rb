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
    # @param [String] progname is used as the logger's program name
    # @param [Integer/Symbol] base_level is the level at which the logger is
    #        initialized, this can be either a symbol from [:DEBUG, :INFO, :WARN,
    #        :ERROR, :FATAL] or the integer constants from Logger::DEBUG,
    #        Logger::INFO, etc.  This value is overriden if the BASE_LOG_LEVEL
    #        environment variable is set.
    #
    # If a block is given, it will be provided the message severity, time,
    # program name and text and should return the formatted message.
    #
    # This method creates a +logger+ attribute in which the module can be
    # accessed. Moreover, it includes Logger::Forward, which allows to access
    # the logger's output methods on the module directly
    #
    # @example
    #   module MyModule
    #       extend Logger.Root('MyModule', Logger::WARN)
    #   end
    #
    #   MyModule.info "text"
    #   MyModule.warn "warntext"
    #
    def self.Root(progname, base_level, &block)
	begin	
	    base_level = ENV['BASE_LOG_LEVEL'].upcase.to_sym if ENV['BASE_LOG_LEVEL']
	    base_level = Logger.const_get( base_level ) if base_level.is_a? Symbol
	rescue Exception => e
	    raise ArgumentError, "Log level #{base_level} is not available in the ruby Logger"
	end

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

                logger = ::Logger.new(STDOUT)
                logger.level = base_level
                logger.progname = progname
                logger.formatter = formatter
                @__utilrb_hierarchy__default_logger = logger
            end
        end
    end
end

