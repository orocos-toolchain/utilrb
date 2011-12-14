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
    # This module is usually used in conjunction with the Logger::Root method:
    # 
    #   module First
    #     include Logger.Root("First", :INFO)
    #
    #     module Second
    #       include Hierarchy
    #     end
    #   end
    #
    # Second.logger will return First.logger. If we do Second.make_own_logger,
    # then a different object will be returned.
    module Hierarchy
        # Allows to change the logger object at this level of the hierarchy
        #
        # This is usually not used directly: a new logger can be created with
        # Hierarchy#make_own_logger and removed with Hierarchy#reset_own_logger
        attr_writer :logger

        def self.included(obj) # :nodoc:
            if obj.singleton_class.ancestors.include?(Logger::Forward)
                obj.send(:include, Logger::Forward)
            end
        end

        def self.extended(obj) # :nodoc:
            if obj.kind_of?(Module)
                parent_module = constant(obj.spacename)
                if (parent_module.singleton_class.ancestors.include?(Logger::Forward))
                    obj.send(:extend, Logger::Forward)
                end
            end
        end

        # Returns true if the local module has its own logger, and false if it
        # returns the logger of the parent
        def has_own_logger?
            defined?(@logger) && @logger
        end

        # Makes it so that this level of the module hierarchy has its own
        # logger. If +new_progname+ and/or +new_level+ are nil, the associated
        # value are taken from the parent's logger.
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

        # Removes a logger defined at this level of the module hierarchy. The
        # logging methods will now access the parent's module logger.
        def reset_own_logger
            @logger = nil
        end

        # Returns the logger object that should be used to log at this level of
        # the module hierarchy
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


