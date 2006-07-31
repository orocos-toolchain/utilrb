class Module
    alias :__instance_include__  :include
    # Includes a module in this one, with singleton class inclusion
    # If a module defines a ClassExtension submodule, then 
    # the module itself is included normally, and ClassExtension 
    # is included in the target singleton class
    def include(mod)
        __instance_include__ mod
        begin
            extend mod.const_get(:ClassExtension)
        rescue NameError => e
	    raise unless e.name == :ClassExtension
        end
    end
end

