require "set"
require "shellwords"

module Utilrb
    # Access to information from pkg-config(1)
    #
    # This class allows to enumerate the pkg-config packages available, and
    # create a PkgConfig object that allows to get access to the pkgconfig
    # information.
    #
    # Create a new pkgconfig object with
    #
    #   pkg = PkgConfig.new(name)
    #
    # It raises PkgConfig::NotFound if the package is not available.
    #
    # Then, the classical include directory and library directory flags can be
    # listed with
    #
    #   pkg.include_dirs
    #   pkg.library_dirs
    #
    # Standard fields are available with
    #
    #   pkg.cflags
    #   pkg.cflags_only_I
    #   pkg.cflags_only_other
    #   pkg.libs
    #   pkg.libs_only_L
    #   pkg.libs_only_l
    #   pkg.libs_only_other
    #   pkg.static
    #
    # Arbitrary variables defined in the .pc file can be accessed with
    # 
    #   pkg.prefix
    #   pkg.libdir
    #
    class PkgConfig
        PACKAGE_NAME_RX = /[\w\-\.]+/
        VAR_NAME_RX     = /\w+/
        FIELD_NAME_RX   = /[\w\.\-]+/

        def self.load(path, preset_variables)
            pkg_name = File.basename(path, ".pc")
            pkg = Class.instance_method(:new).bind(PkgConfig).call(pkg_name)
            pkg.load(path, preset_variables)
            pkg
        end

        def self.load_minimal(path, preset_variables)
            pkg_name = File.basename(path, ".pc")
            pkg = Class.instance_method(:new).bind(PkgConfig).call(pkg_name)
            pkg.load_minimal(path, preset_variables)
            pkg
        end

        # @deprecated {PkgConfig} does not cache the packages anymore, so no
        #   need to call this method
        def self.clear_cache
        end

        # Returns the pkg-config object that matches the given name, and
        # optionally a version string
        def self.get(name, version_spec = nil, preset_variables = Hash.new,
            minimal: false, pkg_config_path: self.pkg_config_path, memo: Hash.new)

            paths = find_all_package_files(name, pkg_config_path: pkg_config_path)
            if paths.empty?
                raise NotFound.new(name), "cannot find the pkg-config specification for #{name}"
            end

            candidates = paths.map do |p|
                PkgConfig.load_minimal(p, preset_variables)
            end

            # Now try to find a matching spec
            if match = find_matching_version(candidates, version_spec)
                memo[[name, version_spec]] = [false, match]
            else
                raise NotFound, "found #{candidates.size} packages for #{name},"\
                    " but none match the version specification #{version_spec}"
            end

            match.load_fields(memo: memo) unless minimal

            memo[[name, version_spec]] = [true, match]
            match
        end

        # Finds the provided package and optional version and returns its
        # PkgConfig description
        #
        # @param [String] version_spec version specification, of the form "op
        # number", where op is < <= >= > or == and the version number X, X.y,
        # ...
        # @return [PkgConfig] the pkg-config description
        # @raise [NotFound] if the package is not found
        def self.new(name, version_spec = nil, **options)
            get(name, version_spec, **options)
        end

        # Returns the first package in +candidates+ that match the given version
        # spec
        def self.find_matching_version(candidates, version_spec)
            if version_spec
                version_spec =~ /([<>=]+)\s*([\d\.]+)/
                op, requested_version = $1, $2

                requested_op =
                    if op == "=" then [0]
                    elsif op == ">" then [1]
                    elsif op == "<" then [-1]
                    elsif op == "<=" then [-1, 0]
                    elsif op == ">=" then [1, 0]
                    end

                requested_version = requested_version.split('.').map { |v| Integer(v) }

                result = candidates.find do |pkg|
                    requested_op.include?(pkg.version <=> requested_version)
                end
                if !result
                    name = candidates.first.name
                    raise NotFound.new(name), "no version of #{name} match #{version_spec}. Available versions are: #{candidates.map(&:raw_version).join(", ")}"
                end
                result
            else
                candidates.first
            end
        end

    # Exception raised when a request pkg-config file is not found
	class NotFound < RuntimeError
            # The name of the pkg-config package
	    attr_reader :name

	    def initialize(name); @name = name end
	end

    # Exception raised when invalid data is found in a pkg-config file
    class Invalid < RuntimeError
        # The name of the pkg-config package
	    attr_reader :name

	    def initialize(name); @name = name end
    end

    attr_reader :path
	
	# The module name
	attr_reader :name
    attr_reader :description
    
    # The module version as a string
    attr_reader :raw_version
    
    # The module version, as an array of integers
    attr_reader :version

    attr_reader :raw_fields

    # Information extracted from the file
    attr_reader :variables
    attr_reader :fields

    # The list of packages that are Require:'d by this package
    #
    # @return [Array<PkgConfig>]
    attr_reader :requires

	# Create a PkgConfig object for the package +name+
	# Raises PkgConfig::NotFound if the module does not exist
	def initialize(name)
	    @name    = name
	    @fields    = Hash.new
	    @variables = Hash.new
	end

        # Helper method that expands ${word} in +value+ using the name to value
        # map +variables+
        #
        # +current+ is a string that describes what we are expanding. It is used
        # to detect recursion in expansion of variables, and to give meaningful
        # errors to the user
        def perform_substitution(value, variables, current)
            value = value.gsub(/\$\{(\w+)\}/) do |rx|
                expand_name = $1
                if expand_name == current
                    raise "error in pkg-config file #{path}: #{current} contains a reference to itself"
                elsif !(expanded = variables[expand_name])
                    raise "error in pkg-config file #{path}: #{current} contains a reference to #{expand_name} but there is no such variable"
                end
                expanded
            end
            value
        end

        class DependencyLoop < RuntimeError; end

        def self.parse_dependencies(string, allow_loops: false, memo: Hash.new)
            string = string.gsub(',', ' ')
            packages = []
            words = string.split(' ')
            while !words.empty?
                w = words.shift
                if w =~ /[<>=]/
                    version = words.shift
                    if  version =~ /[\d\.]+/
                        packages[-1][1] = "#{w} #{version}"
                    else
                        packages << [version, nil]
                    end
                else
                    packages << [w, nil]
                end
            end
            result = packages.map do |dep|
                finished, pkg = memo[dep]
                if pkg
                    if allow_loops || finished
                        pkg
                    else
                        raise DependencyLoop, "found a dependency loop"
                    end
                else
                    PkgConfig.get(*dep, memo: memo)
                end
            end
            result.compact
        end

        SHELL_VARS = %w{Cflags Libs Libs.private}

        # @api private
        #
        # Normalize a field name to be lowercase with only the first letter
        # capitalized
        def normalize_field_name(name)
            name = name.downcase
            name[0, 1] = name[0, 1].upcase
            name
        end

        # Parse a pkg-config field and extracts the raw definition of variables
        # and fields
        #
        # @return [(Hash,Hash)] the set of variables and the set of fields
        def parse(path)
            running_line = nil
            file = File.readlines(path).map do |line|
                line = line.gsub(/\s*#.*$/, '')
                line = line.strip
                next if line.empty?

                value = line.gsub(/\\$/, '')
                if running_line
                    running_line << " " << value
                end

                if line =~ /\\$/
                    running_line ||= value
                elsif running_line
                    running_line = nil
                else
                    value
                end
            end.compact

            raw_variables, raw_fields = Hash.new, Hash.new
            file.each do |line|
                case line
                when /^(#{VAR_NAME_RX})\s*=(.*)/
                    raw_variables[$1] = $2.strip
                when /^(#{FIELD_NAME_RX}):\s*(.*)/
                    field_name = normalize_field_name($1)
                    raw_fields[field_name] = $2.strip
                else
                    raise NotImplementedError, "#{path}: cannot parse pkg-config line #{line.inspect}"
                end
            end
            return raw_variables, raw_fields
        end
        
        def expand_variables(raw_variables)
            raw_variables = raw_variables.dup

            variables = Hash.new
            # Resolve the variables
            while variables.size != raw_variables.size
                raw_variables.each do |name, value|
                    value = perform_substitution(value, raw_variables, name)
                    raw_variables[name] = value
                    if value !~ /\$\{#{VAR_NAME_RX}\}/
                        variables[name] = value
                    end
                end
            end
            variables
        end
        
        def expand_field(name, field)
            if SHELL_VARS.include?(name) 
                value = Shellwords.shellsplit(field)
                resolved = Array.new
                while !value.empty?
                    value = value.flat_map do |v|
                        expanded = perform_substitution(v, variables, name)
                        if expanded == v
                            resolved << v
                            nil
                        else
                            Shellwords.shellsplit(expanded)
                        end
                    end.compact
                end
                resolved
            else
                perform_substitution(field, variables, name)
            end
        end

        def builtin_variables(path)
            {
                "pcfiledir" => File.dirname(path),
                "pc_sysrootdir" => sysrootdir
            }
        end

        def load_variables(path, preset_variables = Hash.new)
            raw_variables, raw_fields = parse(path)
            raw_variables = preset_variables.merge(raw_variables)
            expand_variables(
                raw_variables.merge(builtin_variables(path))
            )
        end
        
        def load_minimal(path, preset_variables = Hash.new)
            raw_variables, raw_fields = parse(path)
            raw_variables = preset_variables.merge(raw_variables)

            @variables = expand_variables(
                raw_variables.merge(builtin_variables(path))
            )
            if raw_fields['Version']
                @raw_version = expand_field('Version', raw_fields['Version'])
            else
                @raw_version = ''
            end
            @version = raw_version.split('.').map { |v| Integer(v) if v =~ /^\d+$/ }.compact

            # To be used in the call to #load
            @raw_fields = raw_fields
            @path = path
        end

        def load_fields(memo: Hash.new)
            fields = Hash.new
            @raw_fields.each do |name, value|
                fields[name] = expand_field(name, value)
            end
            @fields = fields

            # Initialize the main flags
            @description = (fields['Description'] || '')

            # Get the requires/conflicts
            @requires  = PkgConfig.parse_dependencies(
                fields['Requires'] || '', allow_loops: false, memo: memo)
            @requires_private  = PkgConfig.parse_dependencies(
                fields['Requires.private'] || '', allow_loops: false, memo: memo)
            @conflicts = PkgConfig.parse_dependencies(
                fields['Conflicts'] || '', allow_loops: true, memo: memo)

            # And finally resolve the compilation flags
            cflags = fields['Cflags'] || []
            cflags.uniq!
            cflags -= self.class.default_search_path_I
            cflags = apply_sysrootdir(cflags, "-I")
            @requires.each do |pkg|
                cflags.concat(pkg.raw_cflags)
            end
            @requires_private.each do |pkg|
                cflags.concat(pkg.raw_cflags)
            end
            @cflags = cflags

            ldflags_public = fields['Libs'] || []
            ldflags_public.uniq!
            ldflags_private = ldflags_public + (fields['Libs.private'] || [])
            ldflags_private.uniq!

            ldflags_public -= self.class.default_search_path_L
            ldflags_public = apply_sysrootdir(ldflags_public, "-L")
            ldflags_private -= self.class.default_search_path_L
            ldflags_private = apply_sysrootdir(ldflags_private, "-L")
            @ldflags = {
                false => ldflags_public,
                true => ldflags_private
            }

            @ldflags_with_requires = {
                true => @ldflags[true].dup,
                false => @ldflags[false].dup
            }
            @requires.each do |pkg| 
                @ldflags_with_requires[true].concat(pkg.raw_ldflags_with_requires[true])
                @ldflags_with_requires[false].concat(pkg.raw_ldflags_with_requires[false])
            end
            @requires_private.each do |pkg|
                @ldflags_with_requires[true].concat(pkg.raw_ldflags_with_requires[true])
            end
        end

        # Loads the information contained in +path+
        def load(path, preset_variables = Hash.new)
            if !@raw_fields
                load_minimal(path, preset_variables)
            end
            load_fields
        end

	def self.define_pkgconfig_action(action) # :nodoc:
            class_eval <<-EOD, __FILE__, __LINE__+1
            def pkgconfig_#{action.gsub(/-/, '_')}(static = false)
                if static
                    `pkg-config --#{action} --static \#{name}`.strip
                else
                    `pkg-config --#{action} \#{name}`.strip
                end
            end
            EOD
	    nil
	end

        def pkgconfig_variable(varname)
            `pkg-config --variable=#{varname}`.strip
        end

        # Returns the list of include directories listed in the Cflags: section
        # of the pkgconfig file
        def include_dirs
            result = raw_cflags_only_I.map { |v| v[2..-1] }
            if result.any?(&:empty?)
                raise Invalid.new(name), "empty include directory (-I without argument) found in pkg-config package #{name}"
            end

            result
        end

        # Returns the list of library directories listed in the Libs: section
        # of the pkgconfig file
        def library_dirs
            result = raw_libs_only_L.map { |v| v[2..-1] }
            if result.any?(&:empty?)
                raise Invalid.new(name), "empty link directory (-L without argument) found in pkg-config package #{name}"
            end

            result
        end

        # A "new root" that should be prepended to -L and -I flags
        def sysrootdir
            ENV["PKG_CONFIG_SYSROOT_DIR"] || "/"
        end

        # @api private
        #
        # Apply {#sysrootdir} to all the given paths flags (-I or -L)
        def apply_sysrootdir(entries, flag_name)
            sysrootdir = self.sysrootdir
            return entries if sysrootdir == "/"

            entries.map do |v|
                if v.start_with?(flag_name)
                    "#{flag_name}#{sysrootdir}#{v[2..-1]}"
                else
                    v
                end
            end
        end

	ACTIONS = %w{cflags cflags-only-I cflags-only-other 
		    libs libs-only-L libs-only-l libs-only-other}
        ACTIONS.each { |action| define_pkgconfig_action(action) }
    
        def conflicts
            @conflicts
        end

        def raw_cflags
            @cflags
        end

        def raw_cflags_only_I
            @cflags.grep(/^-I/)
        end

        def raw_cflags_only_other
            @cflags.find_all { |s| s !~ /^-I/ }
        end

        def cflags
            raw_cflags.join(" ")
        end

        def cflags_only_I
            raw_cflags_only_I.join(" ")
        end

        def cflags_only_other
            raw_cflags_only_other.join(" ")
        end


        def raw_ldflags
            @ldflags
        end

        def raw_ldflags_with_requires
            @ldflags_with_requires
        end


        def raw_libs(static = false)
            @ldflags_with_requires[static]
        end

        def raw_libs_only_L(static = false)
            @ldflags_with_requires[static].grep(/^-L/)
        end

        def raw_libs_only_l(static = false)
            @ldflags_with_requires[static].grep(/^-l/)
        end

        def raw_libs_only_other(static = false)
            @ldflags_with_requires[static].find_all { |s| s !~ /^-[lL]/ }
        end


        def libs(static = false)
            raw_libs(static).join(" ")
        end

        def libs_only_L(static = false)
            raw_libs_only_L(static).join(" ")
        end

        def libs_only_l(static = false)
            raw_libs_only_l(static).join(" ")
        end

        def libs_only_other(static = false)
            raw_libs_only_other(static).join(" ")
        end

	def method_missing(varname, *args, &proc) # :nodoc:
	    if args.empty?
                variables[varname.to_s]
	    else
		super(varname, *args, &proc)
	    end
	end

        def self.pkg_config_path
            ENV['PKG_CONFIG_PATH']
        end

        def self.each_pkgconfig_directory(pkg_config_path: self.pkg_config_path, &block)
            return enum_for(__method__) if !block_given?
            if pkg_config_path
                pkg_config_path.split(':').each(&block)
            end
            default_search_path.each(&block)
        end

        # Returns true if there is a package with this name
        def self.find_all_package_files(name, pkg_config_path: self.pkg_config_path)
            result = []
            each_pkgconfig_directory(pkg_config_path: pkg_config_path) do |dir|
                path = File.join(dir, "#{name}.pc")
                if File.exist?(path)
                    result << path
                end
            end
            result
        end

        def self.available_package_names(pkg_config_path: self.pkg_config_path)
            result = []
            each_pkgconfig_directory(pkg_config_path: pkg_config_path) do |dir|
                Dir.glob(File.join(dir, "*.pc")) do |path|
                    result << File.basename(path, ".pc")
                end
            end
            result
        end

        # Returns true if there is a package with this name
        def self.has_package?(name, pkg_config_path: self.pkg_config_path)
            !find_all_package_files(name, pkg_config_path: pkg_config_path).empty?
        end

        # Yields the package names of available packages. If +regex+ is given,
        # lists only the names that match the regular expression.
        def self.each_package(regex = nil, pkg_config_path: self.pkg_config_path)
            return enum_for(__method__) if !block_given?

            seen = Set.new
            each_pkgconfig_directory(pkg_config_path: pkg_config_path) do |dir|
                Dir.glob(File.join(dir, '*.pc')) do |file|
                    pkg_name = File.basename(file, ".pc")
                    next if seen.include?(pkg_name)
                    next if regex && pkg_name !~ regex

                    seen << pkg_name
                    yield(pkg_name)
                end
            end
        end


        FOUND_PATH_RX = /Scanning directory (?:#\d+ )?'(.*\/)((?:lib|lib64|share)\/.*)'$/
        NONEXISTENT_PATH_RX = /Cannot open directory (?:#\d+ )?'.*\/((?:lib|lib64|share)\/.*)' in package search path:.*/

        # Returns the system-wide search path that is embedded in pkg-config
        def self.default_search_path
            if !@default_search_path
                output = `LANG=C PKG_CONFIG_PATH= pkg-config --debug 2>&1`.split("\n")
                @default_search_path =
                    output.grep(FOUND_PATH_RX)
                    .map { |l| l.gsub(FOUND_PATH_RX, '\1\2') }
            end
            return @default_search_path
        end
        @default_search_path = nil

        def self.arch_dir
            return if @arch_dir == false

            unless @arch_dir
                suffix_with_arch =
                    default_search_suffixes
                    .find { |p| %r{^lib/[^/]+/pkgconfig} =~ p }

                @arch_dir =
                    if suffix_with_arch
                        suffix_with_arch.split("/")[1]
                    else
                        false
                    end
            end

            @arch_dir
        end

        def self.default_search_path_L
            unless @default_search_path_L
                arch_dir = self.arch_dir
                @default_search_path_L =
                    ["-L/usr/lib", "-L/lib"]
                    .flat_map { |p| [p, "#{p}/#{arch_dir}"] }
            end

            @default_search_path_L
        end

        def self.default_search_path_I
            unless @default_search_path_I
                @default_search_path_I = ["-I/usr/include"]
            end

            @default_search_path_I
        end

        # Returns the system-wide standard suffixes that should be appended to
        # new prefixes to find pkg-config files
        def self.default_search_suffixes
            if !@default_search_suffixes
                output = `LANG=C PKG_CONFIG_PATH= pkg-config --debug 2>&1`.split("\n")
                found_paths = output.grep(FOUND_PATH_RX).
                    map { |l| l.gsub(FOUND_PATH_RX, '\2') }.
                    to_set
                not_found = output.grep(NONEXISTENT_PATH_RX).
                    map { |l| l.gsub(NONEXISTENT_PATH_RX, '\1') }.
                    to_set
                @default_search_suffixes = found_paths | not_found
            end
            return @default_search_suffixes
        end
    end
end

