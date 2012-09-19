class Hash
    def recursive_merge(hash, &block)
        merge(hash) do |k, v1, v2|
            if v1.kind_of?(Hash) && v2.kind_of?(Hash)
                v1.recursive_merge(v2, &block)
            elsif block_given?
                yield(k, v1, v2)
            else
                v2
            end
        end
    end

    def recursive_merge!(hash, &block)
        merge!(hash) do |k, v1, v2|
            if v1.kind_of?(Hash) && v2.kind_of?(Hash)
                v1.recursive_merge!(v2, &block)
            elsif block_given?
                yield(k, v1, v2)
            else
                v2
            end
        end
    end
end

