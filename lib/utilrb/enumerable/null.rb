# A null enumerator which can be used to seed sequence enumeration. See
# Kernel#null_enum
class NullEnumerator
    def each; self end
    include Enumerable
end

module Kernel
    # returns always the same null enumerator, to avoid creating objects. 
    # It can be used as a seed to #inject:
    #
    #   enumerators.inject(null_enum) { |a, b| a + b }.each do |element|
    #   end
    def null_enum
	@@null_enumerator ||= NullEnumerator.new.freeze
    end
end

