if Class.respond_to?(:__metaclass_object__)
    class Class
        def is_singleton?
            !!__metaclass_object__
        end
    end
    class Object
        def is_singleton?
            false
        end
    end
end
