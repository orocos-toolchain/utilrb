require 'utilrb/common'
class Module
    def const_defined_here?(name)
        const_defined?(name, false)
    end
end
