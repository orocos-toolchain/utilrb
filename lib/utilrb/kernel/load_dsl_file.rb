require 'utilrb/common'
require 'utilrb/object/singleton_class'
require 'utilrb/kernel/with_module'

module Kernel
    def load_dsl_filter_backtrace(file, full_backtrace = false, *exceptions)
        our_frame_pos = caller.size - 1

        yield

    rescue Exception => e
        if exceptions.any? { |e_class| e.kind_of?(e_class) }
            raise e
        end

        raise e if full_backtrace

        backtrace = e.backtrace.dup
        message   = e.message.dup

        # Filter out the message ... it can contain backtrace information as
        # well (!)
        message = message.split("\n").map do |line|
            if line =~ /^.*:\d+(:.*)$/
                backtrace.unshift line
                nil
            else
                line
            end
        end.compact.join("\n")


        if message.empty?
            message = backtrace.shift
            if message =~ /^(\s*[^\s]+:\d+:)\s*(.*)/
                location = $1
                message  = $2
                backtrace.unshift location
            else
                backtrace.unshift message
            end
        end

        filtered_backtrace = backtrace[0, backtrace.size - our_frame_pos].
            map do |line|
                if line =~ /load_dsl_file.*(method_missing|send)/
                    next
                end

                if line =~ /^(.*)\(eval\):(\d+)(:.*)?/
                    line_prefix  = $1
                    line_number  = Integer($2) - 1
                    line_message = $3
                    if line_message =~ /_dsl_/ || line_message =~ /with_module/
                        line_message = ""
                    end

                    result = "#{line_prefix}#{file}:#{line_number}#{line_message}"
                else
                    if line =~ /(load_dsl_file\.rb|with_module\.rb):\d+:/
                        next
                    else
                        result = line
                    end
                end
                result

            end.compact


        backtrace = (filtered_backtrace[0, 1] + filtered_backtrace + backtrace[(backtrace.size - our_frame_pos)..-1])
        raise e, message, backtrace
    end

    def eval_dsl_block(block, proxied_object, context, full_backtrace, *exceptions)
        load_dsl_filter_backtrace(nil, full_backtrace, *exceptions) do
            proxied_object.with_module(*context, &block)
            true
        end
    end

    # Load the given file by eval-ing it in the provided binding. The
    # originality of this method is to translate errors that are detected in the
    # eval'ed code into errors that refer to the provided file
    #
    # The caller of this method should call it at the end of its definition
    # file, or the translation method may not be robust at all
    def eval_dsl_file(file, proxied_object, context, full_backtrace, *exceptions, &block)
        if !File.readable?(file)
            raise ArgumentError, "#{file} does not exist"
        end

        loaded_file = file.gsub(/^#{Regexp.quote(Dir.pwd)}\//, '')
        load_dsl_filter_backtrace(file, full_backtrace, *exceptions) do
            file_content = File.read(file)
            sandbox, code = with_module(*context) do
                k = Class.new do
                    attr_accessor :main_object
                    def initialize(obj); @main_object = obj end
                    def method_missing(*m, &block)
                        main_object.send(*m, &block)
                    end
                end

                p = eval <<-EOD
                Proc.new do
                    #{file_content}
                end
                EOD
                [k, p]
            end

            old_constants, new_constants = nil
            if !Utilrb::RUBY_IS_19
                old_constants = Kernel.constants
            end

            sandbox = sandbox.new(proxied_object)
            sandbox.with_module(*context) do
                old_constants = singleton_class.constants
                instance_eval(&code)
                new_constants = singleton_class.constants
            end

            # Check if the user defined new constants by using class K and/or
            # mod Mod
            if !Utilrb::RUBY_IS_19
                new_constants = Kernel.constants
            end

            new_constants -= old_constants
            if !new_constants.empty?
                file_lines = file_content.split("\n").each_with_index.to_a
                error = new_constants.map do |name|
                    file_lines.find { |text, idx| text =~ /#{name}/ }
                end.sort_by { |_, idx| idx }.first
                raise NameError, "#{error[0]} does not exist. You cannot define new constants in this context", ["#{file}:#{error[1] + 1}", *caller]
            end
            true
        end
    end

    # Same than eval_dsl_file, but will not load the same file twice
    def load_dsl_file(*args, &block)
        if $LOADED_FEATURES.include?(file)
            return false
        end

        eval_dsl_file(*args, &block)
        $LOADED_FEATURES << file
        true
    end
end
