require 'utilrb/common'
class Module
    # Check if +klass+ is an ancestor of this class/module
    #
    # It works for singleton classes as well:
    #
    #   class MyClass; end
    #   obj       = MyClass.new
    #   singleton = class << obj; obj end
    #
    #   singleton.has_ancestor?(MyClass) # => true 
    #
    Utilrb.if_faster do
	def has_ancestor?(klass)
	    self == klass || self < klass || (is_singleton? && superclass.has_ancestor?(klass))
	end
    end
    Utilrb.unless_faster do
	def has_ancestor?(klass) # :nodoc:
	    self == klass || self < klass || superclass == klass || superclass < klass
	end
    end
end


