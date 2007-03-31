require 'utilrb/common'
class Module
    # Check if +klass+ is an ancestor of this class/module
    #
    # If Utilrb's C extension is built, works for singleton classes as well:
    #
    #   class MyClass; end
    #   obj       = MyClass.new
    #   singleton = class << obj; obj end
    #
    # With the C extension:
    #   singleton.has_ancestor?(MyClass) # => true 
    #
    # without it
    #   singleton.has_ancestor?(MyClass) # => false 
    #
    Utilrb.if_faster do
	def has_ancestor?(klass)
	    self == klass || self < klass || (is_singleton? && superclass.has_ancestor?(klass))
	end
    end
    Utilrb.unless_faster do
	def has_ancestor?(klass) # :nodoc:
	    self == klass || self < klass
	end
    end
end


