module Kernel
    # Raises if +object+ can accept calls with exactly +arity+ arguments. 
    # object should respond to #arity
    def check_arity(object, arity)
        unless object.arity == arity || (object.arity < 0 && object.arity > - arity - 2)
            raise ArgumentError, "#{object} does not accept to be called with #{arity} argument(s)", caller(2)
        end
    end
end

