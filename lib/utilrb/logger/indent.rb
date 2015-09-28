require 'utilrb/object/attribute'
class Logger
    # The current nest size
    #
    # @return [Integer]
    def nest_size
        @nest_size ||= 0
    end

    # Sets the absolute number of spaces that should be prepended to every
    # message
    #
    # You usually want to increment / decrement this with {nest}
    def nest_size=(new_value)
        @nest_string = nil
        if new_value < 0
            raise ArgumentError, "negative value for nest_size. You probably have unbalanced nest calls"
        end
        @nest_size = new_value
    end

    # Adds a certain number number of spaces to the current indentation level
    #
    # @overload nest(size)
    #   Permanently adds a number of spaces to the current indentation
    #   @param [Integer] size the number of spaces that should be added to
    #     {nest_size}
    #
    # @overload nest(size) { }
    #   Adds a number of spaces to the current indentation for the duration of
    #   the block, and restores the original indentation afterwards.
    #
    #   @param [Integer] size the number of spaces that should be added to
    #     {nest_size}
    #
    # @overload nest(size, log_level) { }
    #   Shortcut for
    #   @example
    #     
    #     logger.send(log_level) do
    #       logger.nest(size) do
    #         ...
    #       end
    #     end
    #
    def nest(size, log_level = nil)
        if log_level
            send(log_level) do
                nest(size) do
                    yield
                end
                return
            end
        end

        if block_given?
            begin
                current = self.nest_size
                self.nest_size += size
                yield
            ensure
                self.nest_size = current
            end
        else
            self.nest_size += size
        end
    end

    # Overloaded from the base logger implementation to add the current
    # indentation
    def format_message(severity, datetime, progname, msg)
        if !@nest_string
            @nest_string = " " * self.nest_size
        end
        msg = "#{@nest_string}#{msg}"
        (@formatter || @default_formatter).call(severity, datetime, progname, msg)
    end
end

