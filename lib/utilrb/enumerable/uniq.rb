require 'enumerator'
require 'set'

# Enumerator object which removes duplicate entries. See
# Object#each_uniq
class UniqEnumerator < Enumerable::Enumerator
    def initialize(root, enum_with, args, key = nil)
	super(root, enum_with, *args)
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

    include Enumerable
end

class Object
    # Enumerate removing the duplicate entries
    def enum_uniq(enum_with = :each, *args, &filter)
	UniqEnumerator.new(self, enum_with, args, filter)
    end
end

module Enumerable
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


