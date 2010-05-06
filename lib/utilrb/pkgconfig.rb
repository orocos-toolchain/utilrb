require 'shellwords'

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
	class NotFound < RuntimeError
	    attr_reader :name
	    def initialize(name); @name = name end
	end
	
	# The module name
	attr_reader :name
	# The module version
	attr_reader :version

	# Create a PkgConfig object for the package +name+
	# Raises PkgConfig::NotFound if the module does not exist
	def initialize(name)
            if !PkgConfig.has_package?(name)
		raise NotFound.new(name), "#{name} is not available to pkg-config"
	    end
	    
	    @name    = name
	    @version = `pkg-config --modversion #{name}`.chomp.strip
	    @actions = Hash.new
	    @variables = Hash.new
	end

	def self.define_action(action) # :nodoc:
	    define_method(action.gsub(/-/, '_')) do 
		@actions[action] ||= `pkg-config --#{action} #{name}`.chomp.strip
	    end
	    nil
	end

        # Returns the list of include directories listed in the Cflags: section
        # of the pkgconfig file
        def include_dirs
            Shellwords.shellsplit(cflags_only_I).map { |v| v[2..-1] }
        end

        # Returns the list of library directories listed in the Libs: section
        # of the pkgconfig file
        def library_dirs
            Shellwords.shellsplit(libs_only_L).map { |v| v[2..-1] }
        end

	ACTIONS = %w{cflags cflags-only-I cflags-only-other 
		    libs libs-only-L libs-only-l libs-only-other static}
	ACTIONS.each { |action| define_action(action) }

	def method_missing(varname, *args, &proc) # :nodoc:
	    if args.empty?
		@variables[varname] ||= `pkg-config --variable=#{varname} #{name}`.chomp.strip
	    else
		super(varname, *args, &proc)
	    end
	end

        def self.each_pkgconfig_directory(&block)
            if path = ENV['PKG_CONFIG_PATH']
                path.split(':').each(&block)
            end
            yield('/usr/local/lib/pkgconfig')
            yield('/usr/lib/pkgconfig')
        end

        # Returns true if there is a package with this name
        def self.has_package?(name)
            each_pkgconfig_directory do |dir|
                if File.exists?(File.join(dir, "#{name}.pc"))
                    return true
                end
            end
            false
        end

        # Yields the package names of available packages. If +regex+ is given,
        # lists only the names that match the regular expression.
        def self.each_package(regex = nil)
            each_pkgconfig_directory do |dir|
                Dir.glob(File.join(dir, '*.pc')) do |file|
                    file = File.basename(file, ".pc")
                    if regex && file !~ regex
                        next
                    end

                    yield(file)
                end
            end
        end
    end
end

