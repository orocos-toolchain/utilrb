class Hash
    # Creates a new hash for in which k => v has been mapped to k => yield(k, v)
    #
    # See also #map_key
    def map_value
        result = Hash.new
        each do |k, v|
            result[k] = yield(k, v)
        end
        result
    end
end

