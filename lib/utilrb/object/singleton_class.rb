require 'utilrb/object/address'

class Class
    unless method_defined?(:__ancestors__)
	alias __ancestors__ ancestors
    end

    attr_reader :singleton_instance

    def ancestors
	if is_singleton?
	    __ancestors__.unshift(self) 
	else
	    __ancestors__
	end
    end
end

class Object
    # Returns true if this object has its own singleton class
    def has_singleton?; defined? @singleton_class end
end

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
	    klass.class_exec do
		unless RUBY_VERSION >= "1.9"
		    @superclass		= instance.class
		    class << self
			attr_reader :superclass
			def name
			    "#{superclass.name}!0x#{@singleton_instance.address.to_s(16)}"
			end
		    end
		end

		@singleton_instance = instance
	    end

	    @singleton_class = klass
	end
    end
end

