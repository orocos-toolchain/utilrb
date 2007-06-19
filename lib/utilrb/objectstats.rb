require 'utilrb/gc/force'
require 'utilrb/object/attribute'
require 'utilrb/column_formatter'

module ObjectStats
    # The count of objects currently allocated
    #
    # It allocates no objects, which means that if
    #	a = ObjectStats.count
    #	b = ObjectStats.count
    #	then a == b
    def self.count
        count = 0
        ObjectSpace.each_object { |obj| count += 1 }

	count
    end

    # Returns a klass => count hash counting the currently allocated objects
    # 
    # It allocates 1 Hash, which is included in the count
    def self.count_by_class
        by_class = Hash.new(0)
        ObjectSpace.each_object { |obj|
            by_class[obj.class] += 1
            by_class
        }

        by_class
    end

    LIVE_OBJECTS_KEY = :live_objects

    # Profiles how much objects has been allocated by the block. Returns a
    # klass => count hash like count_by_class
    #
    # If alive is true, then only live objects are returned.
    def self.profile(alive = false)
	if alive
	    GC.force
	    profile do
		yield
		GC.force
	    end
	end

        already_disabled = GC.disable
        before = count_by_class
	if ObjectSpace.respond_to?(:live_objects)
	    before_live_objects = ObjectSpace.live_objects
	end
        yield
	if ObjectSpace.respond_to?(:live_objects)
	    after_live_objects = ObjectSpace.live_objects
	end
        after  = count_by_class
	if after_live_objects
	    before[LIVE_OBJECTS_KEY] = before_live_objects
	    after[LIVE_OBJECTS_KEY]  = after_live_objects - 1 # correction for yield
	end
        GC.enable unless already_disabled

        after[Hash] -= 1 # Correction for the call of count_by_class
        profile = before.
            merge(after) { |klass, old, new| new - old }.
            delete_if { |klass, count| count == 0 }
    end
end

# BenchmarkAllocation is a Benchmark-like interface to benchmark object allocation. 
#
# == Formatting
# BenchmarkAllocation formats its output in two ways (see examples below)
# * first, each part of a class path is displayed in its own line, to reduce
#   the output width
# * then, output is formatted so that it does not exceed
#   BenchmarkAllocation::SCREEN_WIDTH width
#
#
# == Examples
#
# For instance, 
#
#   require 'utilrb/objectstats'
#   
#   module Namespace
#	class MyClass
#	end
#   end
#
#   BenchmarkAllocation.bm do |x|
#       x.report("array") { Array.new }
#       x.report("hash") { Hash.new }
#       x.report("myclass") { MyClass.new }
#   end
#
# will produce the output
#
#            Array  Hash  Namespace::
#                             MyClass
#     array      1     -            -
#      hash      -     1            -
#   myclass      -     -            1
#  
# Like Benchmark, a rehearsal benchmark method, BenchmarkAllocation.bmbm
# is provided:
#
#   require 'utilrb/objectstats'
#   require 'delegate'
#   
#   module Namespace
#       class MyClass
#       end
#   end
#   
#   delegate_klass = nil
#   BenchmarkAllocation.bmbm do |x|
#       x.report("array") { Array.new }
#       x.report("hash") { Hash.new }
#       x.report("myclass") { Namespace::MyClass.new }
#       x.report("delegate") do
#   	delegate_klass ||= Class.new(DelegateClass(Namespace::MyClass)) do
#   	    def self.name; "Delegate(MyClass)" end
#   	end
#   	delegate_klass.new(Namespace::MyClass.new)
#       end
#   end
#
# produces
#
#   Rehearsal --------------------------------------------------------------------------------
#   
#             Array  Class  Delegate(MyClass)  Hash  Namespace::  String
#                                                        MyClass
#      array      1      -                  -     -            -       -
#       hash      -      -                  -     1            -       -
#    myclass      -      -                  -     -            1       -
#   delegate      5      2                  1     2            1     247
#   ------------------------------------------------------------------------------------------
#   
#             Array  Delegate(MyClass)  Hash  Namespace::
#                                                 MyClass
#      array      1                  -     -            -
#       hash      -                  -     1            -
#    myclass      -                  -     -            1
#   delegate      -                  1     -            1
#   
class BenchmarkAllocation
    SCREEN_WIDTH = 90
    MARGIN = 2

    def self.bm(label_width = nil)
	yield(gather = new)
	gather.format
    end
    def self.bmbm(label_width = nil)
	yield(gather = new)

	title = "Rehearsal"
	puts title + " " + "-" * (SCREEN_WIDTH - title.length - 1)
	gather.format
	puts "-" * SCREEN_WIDTH

	yield(gather = new)
	gather.format
    end

    def format(screen_width = SCREEN_WIDTH, margin = MARGIN)
	data = profiles.map do |label, line_data|
	    line_data['label'] = label
	    line_data
	end
	ColumnFormatter.from_hashes(data, screen_width)
    end

    attribute(:profiles) { Array.new }
    def report(label)
	result = ObjectStats.profile do
	    yield
	end
	result.inject({}) do |result, (klass, count)|
	    klass = klass.to_s
	    klass = "unknown" if !klass || klass.empty?
	    result[klass] = count
	    result
	end
	profiles << [label, result]
    end
end

