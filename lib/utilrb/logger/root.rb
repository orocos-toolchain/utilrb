require 'utilrb/logger/hierarchy'

class Logger
    LEVEL_TO_COLOR =
        begin
            require 'pastel'
            colorizer = Pastel.new
            { 'DEBUG' => ->(t) { t },
              'INFO' =>  ->(t) { t },
              'WARN' =>  colorizer.magenta.detach,
              'ERROR' => colorizer.red.detach,
              'FATAL' => colorizer.red.bold.detach }
        rescue LoadError
            Hash.new
        end

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
            if ENV['BASE_LOG_LEVEL']
                env_level = ENV['BASE_LOG_LEVEL'].upcase.to_sym 
                # there is currently no disabled level on the ruby side
                # but fatal is the closest
                env_level = :FATAL if env_level == :DISABLE
                
                base_level = ::Logger.const_get( env_level ) 
            end
	rescue Exception
	    raise ArgumentError, "Log level #{base_level} is not available in the ruby Logger"
	end

        console = @console
        formatter =
            if block then lambda(&block)
            elsif !LEVEL_TO_COLOR.empty?
                lambda do |severity, time, name, msg|
                    LEVEL_TO_COLOR[severity].call("#{name}[#{severity}]: #{msg}\n")
                end
            else lambda { |severity, time, name, msg| "#{name}[#{severity}]: #{msg}\n" }
            end

        Module.new do
            include ::Logger::Forward
            include ::Logger::HierarchyElement

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

