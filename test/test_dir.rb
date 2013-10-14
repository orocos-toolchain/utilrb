require './test/test_config'

require 'utilrb/dir'
require 'enumerator'

class TC_Dir < Test::Unit::TestCase
    def test_empty
	this_dir = File.dirname(__FILE__)
	assert(!Dir.new(this_dir).empty?)

	begin
	    Dir.mkdir(test_dir_path = File.join(this_dir, 'test_empty') )
	rescue Errno::EEXIST
	end

	test_dir = Dir.new(test_dir_path)
	assert(test_dir.empty?)
    ensure
	Dir.delete(test_dir_path) if test_dir_path
    end
end

