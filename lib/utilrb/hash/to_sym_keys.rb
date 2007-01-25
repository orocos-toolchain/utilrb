class Hash
    # Returns a hash for which all keys have been converted to symbols (only
    # valid for string/symbol keys of course)
    #
    #   { 'a' => 1, :b => '2' }.to_sym_keys => { :a => 1, :b => '2' }
    def to_sym_keys
	inject({}) { |h, (k, v)| h[k.to_sym] = v; h }
    end
end

