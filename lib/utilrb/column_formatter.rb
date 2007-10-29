# Displays a set of data into a column-formatted table
class ColumnFormatter
    MARGIN       = 3
    SCREEN_WIDTH = 90

    # data is an array of hashes. Each line of the array is a line to display,
    # a hash being a column_name => value data set. The special 'label' column
    # name is used to give a name to each line.
    #
    # If a block is given, the method yields the column names and the block must
    # return the array of columns to be displayed, sorted into the order of
    # the columns.
    def self.from_hashes(data, io = STDOUT, margin = MARGIN, screen_width = SCREEN_WIDTH)
	width = Hash.new

	# First, determine the columns width and height, and
	# convert data into strings
	data = data.map do |line_data|
	    line_data = line_data.inject({}) do |h, (label, data)|
		h[label.to_s] = data.to_s
		h
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
	    
	    while !names.empty? && (line_w < screen_width)
		col_n = names.shift
		col_w = width[col_n] || 0
		line_n << col_n
		line_w += col_w
		format << "% #{col_w}s"
	    end

	    format = format.join(" " * margin)
	    io.puts format % line_n
	    data.each do |line_data|
		line_data = line_data.values_at(*line_n)
		line_data.map! { |v| v || '-' }
		io.puts format % line_data
	    end
	end
    end
end

