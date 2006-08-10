require 'utilrb'
require 'pp'

STDERR.puts "== Enumerable#each_uniq =="
test_array = 10000.enum_for(:times).map { rand(10) }
pp ObjectStats.profile { test_array.each_uniq { } }

