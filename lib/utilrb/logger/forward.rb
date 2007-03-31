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
    end
end

