class Logger
    # Forward logger output methods to the logger attribute, so that
    # we can do
    #   module MyModule
    #     extend Logger::Forward
    #   end
    #	MyModule.debug "debug_info"
    # instead of 
    #   MyModule.logger.debug "debug_info"
    # 
    module Forward
        [ :debug, :info, :warn, :error, :fatal, :unknown ].each do |level|
            class_eval <<-EOF, __FILE__, __LINE__+1
                def #{level}(*args, &proc); logger.#{level}(*args, &proc) end
            EOF
        end

        # Forwarded to {Logger#silent}
        def log_silent(&block)
            logger.silent(&block)
        end

        # Forwarded to {Logger#nest}
        def log_nest(size, level = nil, &block)
            logger.nest(size, level, &block)
        end

        # Forwarded to {Logger#log_pp}
        def log_pp(level, object, *first_line_format)
            logger.log_pp(level, object, *first_line_format)
        end
    end
end

