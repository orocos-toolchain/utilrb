
class Object
    if RUBY_VERSION < "2.7.0"
        # Return the object address (for non immediate
        # objects).
        def address
            Object.address_from_id(object_id)
        end
    else
        BUILTIN_OBJECT_TO_S = Object.instance_method(:to_s)
        def address
            to_s = BUILTIN_OBJECT_TO_S.bind(self).call
            if (m = /:(0x[0-9a-f]+)/.match(to_s))
                Integer(m[1])
            end
        end
    end

    # Converts the object_id of a non-immediate object
    # to its memory address
    def self.address_from_id(id)
	id = 0xFFFFFFFFFFFFFFFF - ~id if id < 0
	(id * 2) & 0xFFFFFFFFFFFFFFFF
    end
end

