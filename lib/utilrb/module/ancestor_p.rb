require 'utilrb/common'
class Module
    def has_ancestor?(klass) # :nodoc:
        self <= klass || superclass == klass || superclass < klass
    end
end


