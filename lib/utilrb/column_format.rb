class ColumnFormatter
    MARGIN       = 2
    SCREEN_WIDTH = 90

    def self.from_hashes(data, width = SCREEN_WIDTH)
	width = Hash.new

	# First, determine the columns width and height, and
	# convert data into strings
	data = data.map do |line_data|
	    line_data = line_data.inject({}) do |h, (label, data)|
		h[label.to_s] = data.to_s
	    end
		
	    line_data.each do |label, data|
		unless width.has_key?(label)
		    width[label] = label.length
		end

		if width[label] < data.length
		    width[label] = data.length
		end
	    end
	end

	# Then ask the user to sort the keys for us
	names = width.keys.dup
	names.delete('label')
	names = if block_given? then yield(names)
		else names.sort
		end

	# Finally, format and display
	while !names.empty?
	    # we determine the set of columns to display
	    if width.has_key?('label')
		line_n = ['label']
		line_w = width['label']
		format = ["% #{line_w}s"]
	    else
		line_n = []
		line_w = 0
		format = []
	    end
	    
	    while w < width
		col_n = names.shift
		col_w = width[col_n]
		line_n << col_n
		line_w += col_w
		format << "% #{col_w}s"
	    end

	    puts format % line_n
	    data.each do |line_data|
		puts format % line_data.values_at(*line_n)
	    end
	end
    end
end

