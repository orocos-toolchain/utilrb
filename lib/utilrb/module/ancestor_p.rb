require 'utilrb/common'
class Module
    def has_ancestor?(klass) # :nodoc:
        self <= klass
    end
end
class Class
    def has_ancestor?(klass) # :nodoc:
        # We first test
        #   self <= class
        # as self.superclass goes to the next *CLASS* in the chain, i.e. skips
        # included modules
        #
        # Then, the superclass test is used in case +self+ is a singleton
        self <= klass || (superclass <= klass)
    end
end


