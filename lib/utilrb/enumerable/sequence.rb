class SequenceEnumerator
    extend Forwardable
    def initialize; @sequence = Array.new end

    def <<(object); @sequence << object; self end

    def each
	@sequence.each { |enum| enum.each { |o| yield(o) } } if block_given?
	self
    end

    include Enumerable
end

module Enumerable # :nodoc
    # Build an enumeration sequence with +other_enumerator+
    def +(other_enumerator) # :nodoc
	SequenceEnumerator.new << self << other_enumerator
    end
end


