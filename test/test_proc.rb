require 'utilrb/test'

require 'utilrb'

Utilrb.require_ext('TC_Proc') do
    if RUBY_VERSION =~ /^1\.8/
	class TC_Proc < Minitest::Test
	    def block_to_proc_helper(&block); block end
	    def block_to_proc
		[block_to_proc_helper { blo }, block_to_proc_helper { bla }]
	    end
	    def test_same_body
		a1, a2 = block_to_proc
		b1, b2 = block_to_proc
		assert(a1.same_body?(b1))
		assert(a2.same_body?(b2))
		assert(!a1.same_body?(b2))
		assert(!a2.same_body?(b1))
	    end

	    def test_line
		assert_equal(10, block_to_proc.first.line)
	    end

	    def test_file
		assert_equal(File.expand_path(__FILE__), File.expand_path(block_to_proc.first.file))
	    end
	end
    end
end

