module Kernel
    # Validates an option hash, with default value support
    # 
    # :call-seq:
    #   validate_options(option, hash)       -> options
    #   validate_options(option, array)
    #   validate_options(nil, known_options)
    #
    # In the first form, +option_hash+ should contain keys which are also 
    # in known_hash. The non-nil values of +known_hash+ are used as default
    # values
    #
    # In the second form, +known_array+ is an array of option
    # keys. +option_hash+ keys shall be in +known_array+
    #
    # +nil+ is treated as an empty option hash
    #
    # All option keys are converted into symbols
    #
    def validate_options(options, known_options)
        options = Hash.new unless options
       
        if Array === known_options
            # Build a hash with all values to nil
            known_options = known_options.inject({}) { |h, k| h[k.to_sym] = nil; h }
        end

        options        = options.inject({}) { |h, (k, v)| h[k.to_sym] = v; h }
        known_options  = known_options.inject({}) { |h, (k, v)| h[k.to_sym] = v; h }

        not_valid = options.keys - known_options.keys
        not_valid = not_valid.map { |m| "'#{m}'" }.join(" ")
        raise ArgumentError, "unknown options #{not_valid}", caller(1) if !not_valid.empty?

        # Set default values defined in 'known_options'
        known_options.each_key do |k| 
            value = known_options[k]
	    if !options.has_key?(k) && !value.nil?
		options[k] ||= value
	    end
        end

        options
    end

    def validate_option(options, name, required, message = nil)
        if required && !options.has_key?(name)
            raise ArgumentError, "missing required option #{name}"
        elsif options.has_key?(name) && block_given?
            if !yield(options[name])
                raise ArgumentError, (message || "invalid option value #{options[name]} for #{name}")
            end
        end
    end
end

