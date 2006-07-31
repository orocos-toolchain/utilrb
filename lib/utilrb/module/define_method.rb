class Module
    # Emulate block-passing by converting the block into a Proc object
    # and passing it to the given block as last argument
    # dule)
    #
    # For instance
    #   define_method('my_method') do |a, &block|
    #   end
    #
    # Is written as
    #	define_method_with_block('my_method') do |a, block|
    #	end
    #
    # +block+ is +nil+ if no block is given on the method call
    def define_method_with_block(name, &mdef)
	class_eval <<-EOD
	    def #{name}(*args, &block)
		args << block
		dmwb_#{name}_user_definition(*args) 
	    end
	EOD
	define_method("dmwb_#{name}_user_definition", &mdef)
    end
end

