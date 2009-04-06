require 'enumerator'

# An enumerator which iterates on multiple iterators in sequence
#
#   ([1, 2].enum_for + [2, 3].enum_for).to_a # => [1, 2, 2, 3]
#
# See also Enumerable::Enumerator#+
class SequenceEnumerator
    def initialize; @sequence = Array.new end

    def +(other); SequenceEnumerator.new << self << other end
    # Adds +object+ at the back of the sequence
    def <<(other); @sequence << other; self end

    def each
	@sequence.each { |enum| enum.each { |o| yield(o) } } if block_given?
	self
    end

    include Enumerable
end

enumerator = if defined?(Enumerable::Enumerator)
                 Enumerable::Enumerator
             else
                 Enumerator
             end

enumerator.class_eval do # :nodoc
    # Builds a sequence of enumeration object.
    #	([1, 2].enum_for + [2, 3].enum_for).to_a # => [1, 2, 2, 3]
    def +(other_enumerator) # :nodoc
        SequenceEnumerator.new << self << other_enumerator
    end
end


