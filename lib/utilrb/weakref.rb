require 'utilrb/common'

Utilrb.require_ext("Utilrb::WeakRef") do
    module Utilrb
        class WeakRef
            def initialize(obj)
                if obj.kind_of?(WeakRef)
                    raise ArgumentError, "cannot create a weakref of a weakref"
                end
                    ObjectSpace.define_finalizer(obj, self.class.method(:do_object_finalize))
                do_initialize(obj)
            end
        end
    end
end

