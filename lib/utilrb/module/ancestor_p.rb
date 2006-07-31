class Module
    # Check if +klass+ is an ancestor of this class/module
    def has_ancestor?(klass); ancestors.find { |a| a == klass } end
end


