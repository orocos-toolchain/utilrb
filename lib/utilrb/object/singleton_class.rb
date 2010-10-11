require 'utilrb/common'
require 'utilrb/object/address'

class Object
    if !Object.new.respond_to?(:singleton_class)
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
        class << self; self end
    end
    end
end

