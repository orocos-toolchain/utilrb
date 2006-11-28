class Module
    # Check if +klass+ is an ancestor of this class/module
    def has_ancestor?(klass); self == klass || self < klass end
end


