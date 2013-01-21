require 'set'
module Qt
    class Variant
        # This is a mapping from a QVariant object_id to the object it is
        # supposed to hold. An entry gets removed as soon as the QVariant is
        # finalized
        @@saved_values = Hash.new
        def self.from_ruby(obj, lifetime_object = nil)
            variant = Qt::Variant.new("__##{obj.object_id}#__")
            lifetime_object ||= variant
            ObjectSpace.define_finalizer lifetime_object, from_ruby_finalizer
            @@saved_values[lifetime_object.object_id] ||= Set.new
            @@saved_values[lifetime_object.object_id] << obj
            variant
        end

        def self.from_ruby_finalizer
            lambda { |variant_id| @@saved_values.delete(variant_id) }
        end

        def to_ruby
            raise "QVarint is not storing an Object ID"if (value =~ /__#(\d*)#__/) != 0
            ObjectSpace._id2ref(Integer($1))
        end

        def to_ruby?
            (value =~ /__#(\d*)#__/) == 0
        end
    end
end
