module Kernel
    # Raises if +object+ can accept calls with exactly +arity+ arguments. 
    # object should respond to #arity
    def check_arity(object, arity, strict: nil)
        if strict.nil?
            if object.respond_to?(:lambda?)
                strict = object.lambda?
            else strict = true
            end
        end

        if strict
            if object.arity >= 0 && object.arity != arity
                raise ArgumentError, "#{object} requests #{object.arity} arguments, but #{arity} was requested"
            elsif -object.arity-1 > arity
                raise ArgumentError, "#{object} requests at least #{object.arity} arguments, but #{arity} was requested"
            end
        end
    end
end

