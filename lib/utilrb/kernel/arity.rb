module Kernel
    def check_arity(object, arity)
        unless object.arity == arity || (object.arity < 0 && object.arity > - arity - 2)
            raise ArgumentError, "#{object} does not accept to be called with #{arity} argument(s)"
        end
    end
end

