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
            class_eval <<-EOF
                def #{level}(*args, &proc); logger.#{level}(*args, &proc) end
            EOF
        end

        def log_nest(size, level = nil, &block)
            logger.nest(size, level, &block)
        end

        def log_pp(level, object, *first_line_format)
            logger.log_pp(level, object, *first_line_format)
        end
    end
end

