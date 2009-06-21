# Displays a set of data into a column-formatted table
class ColumnFormatter
    MARGIN       = 1
    SCREEN_WIDTH = 80

    # Formats the given array of hash column-wise.
    #
    # +data+ is an array of hash. In this array, each element is a sample. The
    # column names are defined from the hash keys. If one hash does not have a
    # value for a column, "-" is displayed instead.
    #
    # In the output, the columns are ordered alphabetically by default.
    # Alternatively, they can be ordered by giving an :order option which is an
    # array of string:
    #
    #   from_hashes(data, STDOUT, :order => %w{Col0 Col1 Col2})
    #
    # Finally, the method can yield the set of available columns to a block (if
    # given), and this block should return an ordered array of string.
    #
    # In both cases, columns not listed in the ordering array are not displayed.
    #
    # The formatting can be controlled by the following options:
    # header_delimiter:: 
    #   if true, displays a line of dashes between the header
    #   and the rest of the table
    # column_delimiter::
    #   a string that is inserted between columns
    # left_padding::
    #   a string that is inserted in front of each line
    # order::
    #   an array of column names, defining which columns should be displayed,
    #   and in which order they should be displayed. See above for more
    #   explanations.
    # screen_width::
    #   if the table is wider than this count of characters, it is split into
    #   multiple tables.
    # margin::
    #   defines how many spaces are inserted between two columns.
    def self.from_hashes(data, io = STDOUT, options = Hash.new)
        options = validate_options options, :margin => MARGIN,
            :screen_width => SCREEN_WIDTH,
            :header_delimiter => false,
            :column_delimiter => "",
            :left_padding => "",
            :order => nil

        margin       = options[:margin]
        screen_width = options[:screen_width]

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
	names = if options[:order] then options[:order]
                elsif block_given? then yield(names)
		else names.sort
		end

	# Finally, format and display
	while !names.empty?
	    # we determine the set of columns to display
	    if width.has_key?('label')
		line_n = ['label']
		line_w = width['label']
		format = ["%-#{line_w}s"]
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
		format << "%-#{col_w}s"
	    end

	    format = format.join(" " * margin + options[:column_delimiter] + " " * margin)
            header_line = format % line_n
	    io.puts options[:left_padding] + header_line
            if options[:header_delimiter]
                io.puts options[:left_padding] + "-" * header_line.length
            end

            format = options[:left_padding] + format

	    data.each do |line_data|
		line_data = line_data.values_at(*line_n)
		line_data.map! { |v| v || '-' }
		io.puts format % line_data
	    end
	end
    end
end

