require 'utilrb/object/singleton_class'

class Class
    def superclass_call(name, *args, &block)
	superclass.send(name, *args, &block) if superclass.respond_to?(name)
    end
end

