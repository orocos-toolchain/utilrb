require 'weakref'

module Utilrb
    class WeakRef < ::WeakRef
        def initialize(obj)
            if obj.kind_of?(::WeakRef)
                raise ArgumentError, "cannot create a weakref of a weakref"
            end
            super
        end

        def get
            __getobj__
        end
    end
end

