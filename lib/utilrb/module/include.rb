class Module
    begin
	method(:__instance_include__)
    rescue NameError
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
    def include(*mods)
        mods.each do |mod|
            __include_single_module(mod)
        end
    end

    def __include_single_module(mod)
	if mod.const_defined?(:ModuleExtension)
	    if is_a?(Module)
		unless const_defined?(:ModuleExtension)
		    const_set(:ModuleExtension, Module.new)
		end
		const_get(:ModuleExtension).class_eval do
		    __instance_include__ mod.const_get(:ModuleExtension)
		end
		extend mod.const_get(:ModuleExtension)
	    end
            # Do nothing on classes
	end
	if mod.const_defined?(:ClassExtension)
	    if !is_a?(Class)
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

	__instance_include__ mod
    end
end

