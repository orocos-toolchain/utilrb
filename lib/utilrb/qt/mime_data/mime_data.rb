require 'set'
module Qt
    class MimeData
        # prevents deleting the object until it get finalized by c++
        @@saved_values = Hash.new
        def initialize
            super
            ObjectSpace.define_finalizer self, MimeData::ruby_finalizer
            @@saved_values[self.object_id] ||= Set.new
            @@saved_values[self.object_id] << self
        end

        def self.ruby_finalizer
            lambda { |id| @@saved_values.delete(id) }
        end
    end
end

