class Hash
    def slice(*keys)
	keys.inject({}) { |h, k| h[k] = self[k]; h }
    end
end

