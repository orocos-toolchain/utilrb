require 'facets/module/dirname'
require 'facets/kernel/constant'
class Logger
    # Define a hierarchy of loggers mapped to the module hierarchy.
    # It defines the #logger accessor which either returns the logger
    # attribute of the module, if one is defined, or its parent logger
    # attribute.
    # 
    # module First
    #   include Hierarchy
    #   self.logger = Logger.new
    #
    #   module Second
    #     include Hierarchy
    #   end
    # end
    #
    # Second.logger will return First.logger. If we do
    # Second.logger = Logger.new, then this one would
    # be returned.
    module Hierarchy
        attr_writer :logger
        def logger
            return @logger if defined?(@logger) && @logger
	    @logger = if kind_of?(Module)
			  constant(self.dirname).logger
		      else
			  self.class.logger
		      end
        end
    end
end


