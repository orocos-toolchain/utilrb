class Module
    unless (method(:__instance_include__) rescue nil)
	alias :__instance_include__  :include
    end

    # Includes a module in this one, with support for class extensions
    #
    # If a module defines a ClassExtension submodule, then 
    # * if it is included in a module, the target's ClassExtension
    #   module includes the source ClassExtension (and if there is no
    #   ClassExtension in the target, it is created)
    # * if it is included in a Class, the ClassExtension module
    #   extends the class.
    def include(mod)
	__instance_include__ mod
	return unless mod.const_defined?(:ClassExtension)

	if is_a?(Module) && !is_a?(Class)
	    unless const_defined?(:ClassExtension)
		const_set(:ClassExtension, Module.new)
	    end
	    const_get(:ClassExtension).class_eval do
		__instance_include__ mod.const_get(:ClassExtension)
	    end
	else
	    extend mod.const_get(:ClassExtension)
	end
    end
end

