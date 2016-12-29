class Module
    def has_ancestor?(klass) # :nodoc:
        self <= klass
    end
end


