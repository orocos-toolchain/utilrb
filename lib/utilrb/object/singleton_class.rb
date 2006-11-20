require 'utilrb/object/address'
if RUBY_VERSION >= "1.9"
    class Object
	def has_singleton?; defined? @singleton_class end
	def singleton_class
	    if defined? @singleton_class
		return @singleton_class
	    else
		@singleton_class = class << self
		    class << self
			alias __ancestors__ ancestors
			def ancestors; __ancestors__.unshift(self) end
		    end
		    
		    self 
		end

		@singleton_class
	    end
	end
    end
else
    class Object
	def has_singleton?
	    defined? @singleton_class
	end
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

			alias __ancestors__ ancestors
			def ancestors; __ancestors__.unshift(self) end
		    end
		end

		@singleton_class = klass
	    end
	end
    end
end

