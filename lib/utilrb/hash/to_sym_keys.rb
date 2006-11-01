class Hash
    def to_sym_keys
	inject({}) { |h, (k, v)| h[k.to_sym] = v; h }
    end
end

