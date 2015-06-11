require 'utilrb/common'
class Module
    if Utilrb::RUBY_IS_18
    def const_defined_here?(name)
        const_defined?(name)
    end
    else
    def const_defined_here?(name)
        const_defined?(name, false)
    end
    end
end
