require 'facets/module/spacename'
require 'facets/kernel/constant'
require 'utilrb/object/singleton_class'
require 'utilrb/logger/forward'

class Logger
    # Define a hierarchy of loggers mapped to the module hierarchy.
    #
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

        def self.included(obj)
            if obj.singleton_class.ancestors.include?(Logger::Forward)
                obj.send(:include, Logger::Forward)
            end
        end

        def self.extended(obj)
            if obj.kind_of?(Module)
                parent_module = constant(obj.spacename)
                if (parent_module.singleton_class.ancestors.include?(Logger::Forward))
                    obj.send(:extend, Logger::Forward)
                end
            end
        end

        def has_own_logger?
            defined?(@logger) && @logger
        end

        def make_own_logger(new_progname = nil, new_level = nil)
            if !has_own_logger?
                @logger = self.logger.dup
            end
            if new_progname
                @logger.progname = new_progname
            end
            if new_level
                @logger.level = new_level
            end
            @logger
        end

        def reset_own_logger
            @logger = nil
        end

        def logger
            if defined?(@logger) && @logger
                return @logger 
            elsif defined?(@default_logger) && @default_logger
                return @default_logger
            end

	    @default_logger ||=
                if kind_of?(Module)
                    constant(self.spacename).logger
                else
                    self.class.logger
                end
        end
    end
end


