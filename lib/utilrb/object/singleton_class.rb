require 'utilrb/common'
require 'utilrb/object/address'
require 'utilrb/object/is_singleton_p'

class Object
    if !Object.new.respond_to?(:singleton_class)
    if Object.new.respond_to?(:metaclass)
    # Returns the singleton class for this object.
    def singleton_class
        metaclass
    end
    else
    # Returns the singleton class for this object.
    def singleton_class
        class << self; self end
    end
    end
    end
end

