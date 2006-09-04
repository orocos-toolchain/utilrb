require 'utilrb/gc/force'

module ObjectStats
    # Allocates no object
    def self.count
        count = 0
        ObjectSpace.each_object { |obj| count += 1}

	count
    end

    # Allocates 1 Hash, which is included in the count
    def self.count_by_class
        by_class = Hash.new(0)
        ObjectSpace.each_object { |obj|
            by_class[obj.class] += 1
            by_class
        }
        by_class
    end

    # Profiles the memory allocation in the block
    # If alive is true, then only non-gcable objects
    # are returned.
    def self.profile(alive = false)
        already_disabled = GC.disable
        before = count_by_class
        yield
        after  = count_by_class
        GC.enable unless already_disabled

        after[Hash] -= 1 # Correction for the call of count_by_class
        profile = before.
            merge(after) { |klass, old, new| new - old }.
            delete_if { |klass, count| count == 0 }
    end

    def self.stats(filter = nil)
        total_count = 0
        output = ""
        count_by_class.each do |klass, obj_count|
            total_count += obj_count
            if !filter || klass.name =~ filter
                output << klass.name << " " << obj_count.to_s << "\n"
            end
        end
        
        (output << "Total object count: #{total_count}")
    end
end


