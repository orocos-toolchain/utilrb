require 'utilrb/test'
require 'set'
require 'utilrb/pkgconfig'

class TC_PkgConfig < Minitest::Test
    def setup
	@old_pkg_config_path = ENV['PKG_CONFIG_PATH']
        @pcdir = File.join(File.expand_path(File.dirname(__FILE__)), 'data')
	ENV['PKG_CONFIG_PATH'] = @pcdir
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

    def test_path_autodetection_regexp
        # PkgConfig 0.26
        assert("Scanning directory '/usr/share/pkgconfig'" =~ Utilrb::PkgConfig::FOUND_PATH_RX)
        assert_equal '/usr/share/pkgconfig', "#{$1}#{$2}"
        assert("Cannot open directory '/usr/share/pkgconfig' in package search path:" =~ Utilrb::PkgConfig::NONEXISTENT_PATH_RX)
        assert_equal 'share/pkgconfig', $1

        # PkgConfig 0.29.1
        assert("Scanning directory #10 '/usr/share/pkgconfig'" =~ Utilrb::PkgConfig::FOUND_PATH_RX)
        assert_equal '/usr/share/pkgconfig', "#{$1}#{$2}"
        assert("Cannot open directory #10 '/usr/share/pkgconfig' in package search path:" =~ Utilrb::PkgConfig::NONEXISTENT_PATH_RX)
        assert_equal 'share/pkgconfig', $1
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

	assert_equal(%w{-ltest -lother -Wopt -La_prefix/lib}.to_set, pkg.libs.split.to_set)
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

    IGNORE_COMPARISON_WITH_CPKGCONFIG = [
        # CPkgConfig silently ignores a B package when a
        # requirement has A >= B. We add it instead.
        "test_pkgconfig_version_not_number_and_number",
        "ignition-fuel_tools1",
        "gazebo",
        "test_pkgconfig_recursive_conflict_loop_a",
        "test_pkgconfig_recursive_conflict_loop_b",
        "test_pkgconfig_recursive_require_loop_a",
        "test_pkgconfig_recursive_require_loop_b"
    ]

    def test_comparison_with_cpkgconfig
        PkgConfig.each_package do |name|
            next if IGNORE_COMPARISON_WITH_CPKGCONFIG.include?(name)
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

                pure_ruby_raw    = pkg.send("raw_#{method_name}").to_set
                pure_ruby_joined = Shellwords.shellsplit(pkg.send(method_name)).to_set
                cpkgconfig = Shellwords.shellsplit(pkg.send("pkgconfig_#{method_name}")).to_set
                if pure_ruby_raw != cpkgconfig
                    failed = true
                    puts "#{name} raw_#{action_name}"
                    puts "  pure ruby:  #{pure_ruby_raw.inspect}"
                    puts "  cpkgconfig: #{cpkgconfig.inspect}"
                elsif pure_ruby_joined != cpkgconfig
                    failed = true
                    puts "#{name} #{action_name}"
                    puts "  pure ruby:  #{pure_ruby_joined.inspect}"
                    puts "  cpkgconfig: #{cpkgconfig.inspect}"
                end
            end
            assert(!failed, "result from pkg-config and the PkgConfig class differ")
        end
    end

    def test_comparison_with_cpkgconfig_with_a_different_sysrootdir
        save = ENV["PKG_CONFIG_SYSROOT_DIR"]
        ENV["PKG_CONFIG_SYSROOT_DIR"] = "/some/path/"
        test_comparison_with_cpkgconfig
    ensure
        ENV["PKG_CONFIG_SYSROOT_DIR"] = save
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
        e = assert_raises(Utilrb::PkgConfig::NotFound) do
            Utilrb::PkgConfig.get 'test_pkgconfig_missing_dependency'
        end
        assert e.name == "missing_dependency"
        assert e.message =~ /missing_dependency/
    end

    def test_recursively_resolves_variables_in_shell_fields
        pkg = Utilrb::PkgConfig.get('test_pkgconfig_var_with_multiple_arguments')
        assert_equal '-I/path', pkg.cflags_only_I
        assert_equal '-O3', pkg.cflags_only_other
    end

    def test_dependencies_require_cflags_only_I
        pkg = Utilrb::PkgConfig.get('test_pkgconfig_with_require')
        assert_equal '-Iwith_requires -Ia_prefix/include',
            pkg.cflags_only_I
    end

    def test_dependencies_require_cflags_only_other
        pkg = Utilrb::PkgConfig.get('test_pkgconfig_with_require')
        assert_equal '-Owith_requires -O3',
            pkg.cflags_only_other
    end

    def test_dependencies_require_libs_only_l
        pkg = Utilrb::PkgConfig.get('test_pkgconfig_with_require')
        assert_equal '-lwith_requires -ltest -lother',
            pkg.libs_only_l
    end

    def test_dependencies_require_libs_only_L
        pkg = Utilrb::PkgConfig.get('test_pkgconfig_with_require')
        assert_equal '-Lwith_requires -La_prefix/lib',
            pkg.libs_only_L
    end

    def test_dependencies_require_libs_only_other
        pkg = Utilrb::PkgConfig.get('test_pkgconfig_with_require')
        assert_equal '-Wwith_requires -Wopt',
            pkg.libs_only_other
    end

    def test_requires
        pkg = Utilrb::PkgConfig.get('test_pkgconfig_with_require')
        assert_equal ['test_pkgconfig'],
            pkg.requires.map(&:name)
    end

    def test_recursive_conflicts
        pkg = Utilrb::PkgConfig.parse_dependencies('test_pkgconfig_recursive_conflict_loop_a')[0]
        assert_equal ['test_pkgconfig_recursive_conflict_loop_b', 'test_pkgconfig_recursive_conflict_loop_c'],
            pkg.conflicts.map(&:name)

        pkg = Utilrb::PkgConfig.parse_dependencies('test_pkgconfig_recursive_conflict_loop_b')[0]
        assert_equal ['test_pkgconfig_recursive_conflict_loop_a', 'test_pkgconfig_recursive_conflict_loop_b', 'test_pkgconfig_recursive_conflict_loop_d'],
            pkg.conflicts.map(&:name)
    end

    def test_recursive_requires
        e = assert_raises(Utilrb::PkgConfig::DependencyLoop) do
            Utilrb::PkgConfig.parse_dependencies 'test_pkgconfig_recursive_require_loop_a'
        end
    end

    def test_recursive_conflict_full_list
        # A conflicts [B, C]
        # B conflicts [A, B, D]

        # When parsing A
        pkgA = Utilrb::PkgConfig.parse_dependencies('test_pkgconfig_recursive_conflict_loop_a')[0]
        assert_equal ['test_pkgconfig_recursive_conflict_loop_b', 'test_pkgconfig_recursive_conflict_loop_c'],
            pkgA.conflicts.map(&:name)

        # B is the first conflict and it should conflict with [A, B, D]
        pkgB = pkgA.conflicts[0]
        assert_equal ['test_pkgconfig_recursive_conflict_loop_a', 'test_pkgconfig_recursive_conflict_loop_b', 'test_pkgconfig_recursive_conflict_loop_d'],
            pkgB.conflicts.map(&:name)

        # When parsing B
        pkgB = Utilrb::PkgConfig.parse_dependencies('test_pkgconfig_recursive_conflict_loop_b')[0]
        assert_equal ['test_pkgconfig_recursive_conflict_loop_a', 'test_pkgconfig_recursive_conflict_loop_b', 'test_pkgconfig_recursive_conflict_loop_d'],
            pkgB.conflicts.map(&:name)
        
        # A is the first conflict and it should conflict with [B, C]
        pkgA = pkgB.conflicts[0] 
        assert_equal ['test_pkgconfig_recursive_conflict_loop_b', 'test_pkgconfig_recursive_conflict_loop_c'],
            pkgA.conflicts.map(&:name)
    end

    def test_malformed_version_not_number
        pkg = Utilrb::PkgConfig.parse_dependencies('test_pkgconfig_version_not_number')[0]
        assert_equal ['test_pkgconfig_recursive_require_loop_c', 'test_pkgconfig_recursive_require_loop_d'],
            pkg.requires.map(&:name)
    end

    def test_malformed_version_not_number_and_number
        pkg = Utilrb::PkgConfig.parse_dependencies('test_pkgconfig_version_not_number_and_number')[0]
        assert_equal ['test_pkgconfig_recursive_require_loop_c', 'test_pkgconfig_recursive_require_loop_d'],
            pkg.requires.map(&:name)  
    end

    def test_recursive_noloop_require
        # A requires [B, C]
        # B requires [C] this is not a loop, but C is required two times
        pkgA = Utilrb::PkgConfig.parse_dependencies('test_pkgconfig_recursive_noloop_require_a')[0]
        assert_equal ['test_pkgconfig_recursive_noloop_require_b', 'test_pkgconfig_recursive_noloop_require_c'],
            pkgA.requires.map(&:name)

        # B is the first conflict and it should conflict with [A, B, D]
        pkgB = pkgA.requires[0]
        assert_equal ['test_pkgconfig_recursive_noloop_require_c'],
            pkgB.requires.map(&:name)
    end

    def test_pcfiledir
        pkg = Utilrb::PkgConfig.get('test_pcfiledir')
        assert_equal "-I#{@pcdir}/../../include", pkg.cflags_only_I
    end

    def test_it_expands_pc_sysrootdir_to_root_by_default
        pkg = Utilrb::PkgConfig.get('test_pc_sysrootdir')
        assert_equal "/", pkg.variables["somevar"]
    end

    def test_it_expands_pc_sysrootdir_to_the_PKG_CONFIG_SYSROOT_DIR_environment_variable_if_set
        save = ENV["PKG_CONFIG_SYSROOT_DIR"]
        ENV["PKG_CONFIG_SYSROOT_DIR"] = "/some/path"
        pkg = Utilrb::PkgConfig.get('test_pc_sysrootdir')
        assert_equal "/some/path", pkg.variables["somevar"]
    ensure
        ENV["PKG_CONFIG_SYSROOT_DIR"] = save
    end
end
