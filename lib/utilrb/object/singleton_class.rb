if RUBY_VERSION >= "1.9"
    class Object
	def singleton_class
	    class << self; self end
	end
    end
else
    class Object
	def singleton_class
	    if defined? @singleton_class
		return @singleton_class
	    else
		klass = class << self; self end
		instance = self
		klass.class_eval do
		    @singleton_instance = instance
		    class << self
			attr_reader :singleton_instance
			#def name; @singleton_instance.class.name end
		    end
		end

		@singleton_class = klass
	    end
	end
    end
end


