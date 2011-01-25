require 'utilrb/module/const_defined_here_p'
class Module
    # :call-seq
    #   define_or_reuse(name, value)   ->              value
    #   define_or_reuse(name) { ... }  ->              value
    #
    # Defines a new constant under a given module, or reuse the
    # already-existing value if the constant is already defined.
    #
    # In the first form, the method gets its value from its argument. 
    # In the second case, it calls the provided block
    def define_or_reuse(name, value = nil)
        if const_defined_here?(name)
            const_get(name)
        else
            module_eval do
                const_set(name, (value || yield))
            end
        end
    end
end

