require 'utilrb/test'
require 'set'
require 'utilrb/pkgconfig'

class TC_PkgConfig < Minitest::Test
    def setup
	@old_pkg_config_path = ENV['PKG_CONFIG_PATH']
	ENV['PKG_CONFIG_PATH'] = File.join(File.expand_path(File.dirname(__FILE__)), 'data')
    end
    def teardown
	ENV['PKG_CONFIG_PATH'] = @old_pkg_config_path
    end

    PkgConfig = Utilrb::PkgConfig
    def test_find_package
	assert_raises(PkgConfig::NotFound) { PkgConfig.new('does_not_exist') }
        # Should not raise
	PkgConfig.new('test_pkgconfig')
    end

    def test_load
	pkg = PkgConfig.new('test_pkgconfig')
	assert_equal('test_pkgconfig', pkg.name)
	assert_equal([4, 2], pkg.version)

	assert_equal('a_prefix', pkg.prefix)
	assert_equal(%w{-Ia_prefix/include -O3}.to_set, pkg.cflags.split.to_set)
	assert_equal('-Ia_prefix/include', pkg.cflags_only_I)
	assert_equal('-O3', pkg.cflags_only_other)
        assert_equal(['a_prefix/include'], pkg.include_dirs)

	assert_equal(%w{-ltest -lother -La_prefix/lib}.to_set, pkg.libs.split.to_set)
	assert_equal('-La_prefix/lib', pkg.libs_only_L)
	assert_equal(%w{-ltest -lother}.to_set, pkg.libs_only_l.split.to_set)
        assert_equal(['a_prefix/lib'], pkg.library_dirs)

	pkg = PkgConfig.new('test_pkgconfig_empty')
	assert_equal('a_prefix', pkg.prefix)
	assert_equal("", pkg.cflags)
	assert_equal('', pkg.cflags_only_I)
	assert_equal('', pkg.cflags_only_other)
        assert_equal([], pkg.include_dirs)

	assert_equal('', pkg.libs)
	assert_equal('', pkg.libs_only_L)
	assert_equal('', pkg.libs_only_l)
        assert_equal([], pkg.library_dirs)
    end

    def test_comparison_with_cpkgconfig
        PkgConfig.each_package do |name|
            pkg = begin PkgConfig.new(name)
                  rescue PkgConfig::NotFound
                      `pkg-config --cflags #{name}`
                      if $? == 0
                          raise
                      else
                          puts "can be loaded by neither the ruby nor the C versions"
                          next
                      end
                  end

            failed = false
            PkgConfig::ACTIONS.each do |action_name|
                method_name = action_name.gsub(/-/, '_')

                pure_ruby  = Shellwords.shellsplit(pkg.send(method_name)).to_set
                cpkgconfig = Shellwords.shellsplit(pkg.send("pkgconfig_#{method_name}")).to_set
                default_paths = Utilrb::PkgConfig.default_search_path.map { |p| Regexp.quote(p.gsub(/\/pkgconfig/, '')) }.join("|")
                pure_ruby.delete_if { |f| f=~/-[IL](#{default_paths}|\/lib)$/ }
                cpkgconfig.delete_if { |f| f=~/-[IL](#{default_paths}|\/lib)$/ }
                if pure_ruby != cpkgconfig
                    failed = true
                    puts "#{name} #{action_name}"
                    puts "  pure ruby:  #{pure_ruby.inspect}"
                    puts "  cpkgconfig: #{cpkgconfig.inspect}"
                end
            end
            if failed
                puts "contents:"
                puts pkg.file.join("\n")
                assert(false, "result from pkg-config and the PkgConfig class differ")
            end
        end
    end

    def test_missing_package
        Utilrb::PkgConfig.get 'does_not_exist'
        flunk("Utilrb::PkgConfig.get did not raise on a non existent package")
    rescue Utilrb::PkgConfig::NotFound => e
        assert_equal 'does_not_exist', e.name
        assert(e.message =~ /does_not_exist/)
    end

    def test_missing_package_version
        Utilrb::PkgConfig.get 'test_pkgconfig_package_version', '> 1.0'
        flunk("Utilrb::PkgConfig.get did not raise on a non existent package version")
    rescue Utilrb::PkgConfig::NotFound => e
        assert_equal 'test_pkgconfig_package_version', e.name
        assert(e.message =~ /test_pkgconfig_package_version/, "error message '#{e.message}' does not mention the problematic package")
    end

    def test_missing_dependency
        Utilrb::PkgConfig.get 'test_pkgconfig_missing_dependency'
        flunk("Utilrb::PkgConfig.get did not raise on a missing dependency")
    rescue Utilrb::PkgConfig::NotFound => e
        assert e.name == "missing_dependency"
        assert e.message =~ /missing_dependency/
    end
end
