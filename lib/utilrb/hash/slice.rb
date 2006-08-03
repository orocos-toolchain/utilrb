class Hash
    def slice(*keys)
	keys.inject({}) { |h, k| h[k] = self[k] if has_key?(k); h }
    end
end

