require 'utilrb/gc/force'
require 'utilrb/object/attribute'

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

    # Profiles how much objects has been allocated by the block. Returns a
    # klass => count hash like count_by_class
    #
    # If alive is true, then only live objects are returned.
    def self.profile(alive = false)
        already_disabled = GC.disable
        before = count_by_class
        yield
        after  = count_by_class
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
    MARGIN       = 2
    SCREEN_WIDTH = 90

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
	label_width ||= 0
	column_names = profiles.inject([]) do |column_names, (label, profile)|
	    label_width = label_width < label.length ? label.length : label_width
	    column_names |= profile.keys
	end.sort

	# split at the :: to separate modules and klasses (reduce header sizes)
	blocks = []
	header, columns, current_width = nil
	column_names.each_with_index do |name, col_index|
	    splitted = name.gsub(/::/, "::\n").split("\n")
	    width    = splitted.map { |part| part.length }.max + MARGIN

	    if !current_width || (current_width + label_width + width > screen_width)
		# start a new block
		blocks << [[], []]
		header, columns = blocks.last
		current_width = 0
	    end

	    splitted.each_with_index do |part, line_index|
		if !header[line_index]
		    header[line_index] = columns.map { |_, w| " " * w }
		end
		header[line_index] << "% #{width}s" % [part]
	    end
	    # Pad the remaining lines
	    header[splitted.size..-1].each_with_index do |line, index|
		line << " " * width
	    end

	    columns << [name, width]
	    current_width += width
	end
	    
	blocks.each do |header, columns|
	    puts
	    header.each { |line| puts " " * label_width + line.join("") }

	    profiles.each do |label, profile|
		print "% #{label_width}s" % [label]
		columns.each do |name, width|
		    
		    if count = profile[name] 
			print "% #{width}i" % [profile[name] || 0]
		    else
			print " " * (width - 1) + "-"
		    end
		end
		puts
	    end
	end
    end

    attribute(:profiles) { Array.new }
    def report(label)
	result = ObjectStats.profile do
	    yield
	end
	result.inject({}) do |result, (klass, count)|
	    klass = klass.name
	    klass = "unknown" if !klass || klass.empty?
	    result[klass] = count
	    result
	end
	profiles << [label, result]
    end
end

