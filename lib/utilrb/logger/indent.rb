require 'utilrb/object/attribute'
class Logger
    attribute(:nest_size) { 0 }
    def nest_size=(new_value)
        @nest_string = nil
        @nest_size = new_value
    end

    def nest(size, level = nil)
        if level
            send(level) do
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

    def format_message(severity, datetime, progname, msg)
        if !@nest_string
            @nest_string = " " * self.nest_size
        end
        msg = "#{@nest_string}#{msg}"
        (@formatter || @default_formatter).call(severity, datetime, progname, msg)
    end
end

