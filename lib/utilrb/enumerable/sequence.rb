# An enumerator which iterates on a sequence of enumerator
class SequenceEnumerator
    def initialize; @sequence = Array.new end
    # Adds +object+ at the back of the sequence
    def <<(object); @sequence << object; self end

    def each
	@sequence.each { |enum| enum.each { |o| yield(o) } } if block_given?
	self
    end

    include Enumerable
end

module Enumerable # :nodoc
    # Builds a sequence of enumeration object.
    #	([1, 2].enum_for + [2, 3]).each		=> 1, 2, 2, 3
    def +(other_enumerator) # :nodoc
	SequenceEnumerator.new << self << other_enumerator
    end
end


