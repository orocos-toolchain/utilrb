require 'utilrb/object/address'

class Object
    # Returns true if this object has its own singleton class
    def has_singleton?; defined? @singleton_class end
end

if RUBY_VERSION >= "1.9"
    class Object
	def singleton_class # :nodoc:
	    if defined? @singleton_class
		return @singleton_class
	    else
		@singleton_class = class << self
		    class << self
			alias __ancestors__ ancestors # :nodoc:
			def ancestors # :nodoc:
			    __ancestors__.unshift(self) 
			end
		    end
		    
		    self 
		end

		@singleton_class
	    end
	end
    end
else
    class Object
	# Returns the singleton class for this object.
	#
	# In Ruby 1.8, makes sure that the #superclass method of the singleton class 
	# returns the object's class (instead of Class), as Ruby 1.9 does
	#
	# The first element of #ancestors on the returned singleton class is
	# the singleton class itself. A #singleton_instance accessor is also
	# defined, which returns the object instance the class is the singleton
	# of.
	def singleton_class
	    if defined? @singleton_class
		return @singleton_class
	    else
		klass = class << self; self end
		instance = self
		klass.class_eval do
		    @singleton_instance = instance
		    @superclass		= instance.class
		    class << self
			attr_reader :superclass
			attr_reader :singleton_instance
			def name
			    "#{@superclass.name}!0x#{@singleton_instance.address.to_s(16)}"
			end

			alias __ancestors__ ancestors # :nodoc:
			def ancestors # :nodoc:
			    __ancestors__.unshift(self) 
			end
		    end
		end

		@singleton_class = klass
	    end
	end
    end
end

