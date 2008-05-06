require 'utilrb/common'
class Module
    Utilrb.if_ext do
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
	def has_ancestor?(klass)
	    self <= klass || (is_singleton? && superclass.has_ancestor?(klass))
	end
    end
    Utilrb.unless_ext do
	def has_ancestor?(klass) # :nodoc:
	    self <= klass || superclass == klass || superclass < klass
	end
    end
end


