module Kernel
    # Load the given file by eval-ing it in the provided binding. The
    # originality of this method is to translate errors that are detected in the
    # eval'ed code into 
    #
    # The caller of this method should call it at the end of its definition
    # file, or the translation method may not be robust at all
    def load_dsl_file(file, binding, full_backtrace, *exceptions)
        loaded_file = file.gsub(/^#{Regexp.quote(Dir.pwd)}\//, '')
        caller_string = caller(1)[0].split(':')
        eval_file = caller_string[0]
        eval_line = Integer(caller_string[1])

        if !File.readable?(file)
            raise ArgumentError, "#{file} does not exist"
        end
        Kernel.eval(File.read(file), binding)

    rescue *exceptions
        e = $!
        new_backtrace = e.backtrace.map do |line|
            if line =~ /^(#{Regexp.quote(eval_file)}:)(\d+)(.*)$/
                before, line_number, rest = $1, Integer($2), $3
                if line_number > eval_line
                    if rest =~ /:in `[^']+'/
                        rest = $'
                    end
                    newline = "#{File.expand_path(loaded_file)}:#{line_number - eval_line + 1}#{rest}"

                    if !full_backtrace
                        raise e, e.message, [newline]
                    else newline
                    end
                else line
                end
            else
                line
            end
        end
        raise e, e.message, new_backtrace
    end
end
