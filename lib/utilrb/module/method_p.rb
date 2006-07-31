class Module
    def instance_method?(name)
	!!instance_method(name)
    rescue NameError
    end
end

class Object
    def method?(name)
	!!method(name)
    rescue NameError
    end
end
