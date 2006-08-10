require 'benchmark'
require 'utilrb'

STDERR.puts "== Enumerable#each_uniq =="
test_arrays = []
1000.times { 
    new = []
    1000.times { new << rand(10) }
    test_arrays << new
}

Benchmark.bm(7) do |x|
    x.report('each_uniq') do 
	test_arrays.each do |test|
	    test.each_uniq { }
	end
    end
end

