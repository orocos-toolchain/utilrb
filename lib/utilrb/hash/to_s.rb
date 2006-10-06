class Hash
    def to_s
	map { |k, v| "#{k} => #{v}" }.join(", ")
    end
end

