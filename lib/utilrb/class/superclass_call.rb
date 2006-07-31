require 'utilrb/object/singleton_class'

if RUBY_VERSION >= "1.9"
    class Class
	def superclass_call(name, *args, &block)
	    superclass.send(name, *args, &block) if superclass.respond_to?(name)
	end
    end
else
    class Class
	def superclass_call(name, *args, &block)
	    klass = if respond_to?(:singleton_instance)
			# Emulate the behaviour of Ruby 1.9
			singleton_instance.class
		    else
			superclass
		    end
	    klass.send(name, *args, &block) if klass.respond_to?(name)
	end
    end
end

