begin
    require "highline"
rescue LoadError
end

require 'utilrb/exception/full_message'
class Logger
    def self.pp_to_array(object)
        message =
            begin
                PP.pp(object, "")
            rescue Exception => formatting_error
                begin
                  "error formatting object using pretty-printing\n" +
                      object.to_s +
                  "\nplease report the formatting error: \n" + 
                  formatting_error.full_message
                rescue Exception => formatting_error
                  "\nerror formatting object using pretty-printing\n" +
                      formatting_error.full_message
                end
            end

        message.split("\n")
    end

    if defined? HighLine
        def color(*args)
            @color_generator ||= HighLine.new
            @color_generator.color(*args)
        end
    end

    def log_pp(level, object, *first_line_format)
        send(level) do
            first_line = !first_line_format.empty? && defined?(HighLine)
            self.class.pp_to_array(object).each do |line|
                if first_line
                    line = color(line, *first_line_format)
                    first_line = false
                end
                send(level, line)
            end
            break
        end
    end
end

