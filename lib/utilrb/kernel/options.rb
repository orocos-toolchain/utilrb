require 'utilrb/hash/to_sym_keys'
require 'utilrb/hash/slice'
module Kernel
    # Partitions an option hash between known arguments and unknown
    # arguments, with default value support. All option keys are
    # converted to symbols for consistency.
    #
    # The following rules apply:
    #   * if a hash is given, non-nil values are treated as default values.
    #   * an array is equivalent to a hash where all values are 'nil'
    #
    # See #validate_options and #filter_and_validate_options
    #
    # call-seq:
    #   filter_options(option, hash)       -> known, unknown
    #   filter_options(option, array)	   -> known, unknown
    #   filter_options(nil, known_options) -> default_options, {}
    #
    def filter_options(options, option_spec)
        options     = (options || Hash.new).to_sym_keys
	# cannot use #to_sym_keys as option_spec can be an array
	option_spec = option_spec.inject({}) { |h, (k, v)| h[k.to_sym] = v; h }

	unknown_options = options.slice(*(options.keys - option_spec.keys))
	known_options   = options.slice(*option_spec.keys)

        # Set default values defined in the spec
        option_spec.each_key do |k| 
            value = option_spec[k]
	    if !known_options.has_key?(k) && !value.nil?
		known_options[k] ||= value
	    end
        end

        return *[known_options, unknown_options]
    end

    # Validates an option hash, with default value support. See #filter_options
    # 
    # In the first form, +option_hash+ should contain keys which are also 
    # in known_hash. The non-nil values of +known_hash+ are used as default
    # values. In the second form, +known_array+ is an array of option
    # keys. +option_hash+ keys shall be in +known_array+. +nil+ is treated 
    # as an empty option hash, all keys are converted into symbols.
    #
    def validate_options(options, known_options)
	opt, unknown = Kernel.filter_options(options, known_options)
	unless unknown.empty?
	    not_valid = unknown.keys.map { |m| "'#{m}'" }.join(" ")
	    raise ArgumentError, "unknown options #{not_valid}", caller(1)
	end

	opt
    end

    # call-seq:
    #	validate_option(options, name, required, message) { |v| ... }
    #	validate_option(options, name, required, message)
    #
    # Validates option +name+ in the +options+ hash. If required is true,
    # raises ArgumentError if the option is not present. Otherwise, yields
    # its value to an optional block, which should return if the value is
    # valid, or false otherwise. If the value is invalid, raises ArgumentError
    # with +message+ or a standard message.
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

