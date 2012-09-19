class Hash
    # Creates a new hash for in which k => v has been mapped to yield(k, v) => v
    #
    # See also #map_value
    def map_key
        result = Hash.new
        each do |k, v|
            result[yield(k, v)] = v
        end
        result
    end
end

