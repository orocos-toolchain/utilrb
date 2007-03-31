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
    #	define_method_with_block('my_method') do |block, a|
    #	end
    #
    # The block is given first to allow the following construct:
    #
    #	define_method_with_block('my_method') do |block, *args|
    #	end
    #
    # +block+ is +nil+ if no block is given during the method call
    #
    def define_method_with_block(name, &mdef)
	class_eval <<-EOD
	    def #{name}(*args, &block)
		dmwb_#{name}_user_definition(block, *args) 
	    end
	EOD
	define_method("dmwb_#{name}_user_definition", &mdef)
    end
end

