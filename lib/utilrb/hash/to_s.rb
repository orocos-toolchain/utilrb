class Hash
    # Displays hashes as { a => A, b => B, ... } instead of the standard #join
    # Unlike #inspect, it calls #to_s on the elements too
    def to_s
	"{" << map { |k, v| "#{k} => #{v}" }.join(", ") << "}"
    end
end

