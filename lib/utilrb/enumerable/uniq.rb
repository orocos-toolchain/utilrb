require 'utilrb/common'
require 'enumerator'
require 'set'

# Enumerator object which removes duplicate entries. 
# See also Object#enum_uniq and Enumerable#each_uniq
class UniqEnumerator < Enumerable::Enumerator
    # Creates the enumerator on +obj+ using the method +enum_with+ to
    # enumerate. The method will be called with the arguments in +args+.
    #
    # If +key+ is given, it is a proc object which should return the key on
    # which we base ourselves to compare two objects. If it is not given,
    # UniqEnumerator uses the object itself
    #
    # See also Object#enum_uniq and Enumerable#each_uniq
    def initialize(obj, enum_with, args, key = nil)
	super(obj, enum_with, *args)
	@key = key
	@result = Hash.new
    end

    def each
	if block_given?
	    @result.clear
	    result = @result
	    super() do |v|
		k = @key ? @key.call(v) : v

		if !result.has_key?(k)
		    result[k] = v
		    yield(v)
		end
	    end

	    result.values
	else
	    self
	end
    end
end

class Object
    # Enumerate using the <tt>each(*args)</tt> method, removing the duplicate
    # entries. If +filter+ is given, it should return an object the enumerator
    # will compare for equality (instead of using the objects themselves)
    def enum_uniq(enum_with = :each, *args, &filter)
	UniqEnumerator.new(self, enum_with, args, filter)
    end
end

Utilrb.unless_faster do
    module Enumerable
	# call-seq:
	#  each_uniq { |obj| ... }
	# 
	# Yields all unique values found in +enum+
	def each_uniq(&iterator)
	    seen = Set.new
	    each do |obj|
		if !seen.include?(obj)
		    seen << obj
		    yield(obj)
		end
	    end
	end
    end
end

