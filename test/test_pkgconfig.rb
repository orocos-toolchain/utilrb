require 'test/unit'
require 'set'
require 'utilrb/pkgconfig'

class TC_PkgConfig < Test::Unit::TestCase
    def setup
	@old_pkg_config_path = ENV['PKG_CONFIG_PATH']
	ENV['PKG_CONFIG_PATH'] = File.join(File.expand_path(File.dirname(__FILE__)), 'data')
    end
    def teardown
	ENV['PKG_CONFIG_PATH'] = @old_pkg_config_path
    end

    PkgConfig = Utilrb::PkgConfig
    def test_find_package
	STDERR.puts ENV['PKG_CONFIG_PATH']
	assert_raises(PkgConfig::NotFound) { PkgConfig.new('does_not_exist') }
	assert_nothing_raised { PkgConfig.new('test_pkgconfig') }
    end

    def test_load
	pkg = PkgConfig.new('test_pkgconfig')
	assert_equal('test_pkgconfig', pkg.name)
	assert_equal('4.2', pkg.version)

	assert_equal('a_prefix', pkg.prefix)
	assert_equal(%w{-Ia_prefix/include -O3}.to_set, pkg.cflags.split.to_set)
	assert_equal('-Ia_prefix/include', pkg.cflags_only_I)
	assert_equal('-O3', pkg.cflags_only_other)

	assert_equal(%w{-ltest -lother -La_prefix/lib}.to_set, pkg.libs.split.to_set)
	assert_equal('-La_prefix/lib', pkg.libs_only_L)
	assert_equal(%w{-ltest -lother}.to_set, pkg.libs_only_l.split.to_set)
    end
end
