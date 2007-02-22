class Module
    # Check if +klass+ is an ancestor of this class/module
    def has_ancestor?(klass)
	self == klass || self < klass || (is_singleton? && superclass.has_ancestor?(klass))
    end
end


