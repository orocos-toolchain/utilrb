require 'shellwords'

module Utilrb
    # Access to information from pkg-config(1)
    class PkgConfig
	class NotFound < RuntimeError
	    attr_reader :name
	    def initialize(name); @name = name end
	    def to_s; "#{name} is not available to pkg-config" end
	end
	
	# The module name
	attr_reader :name
	# The module version
	attr_reader :version

	# Create a PkgConfig object for the package +name+
	# Raises PkgConfig::NotFound if the module does not exist
	def initialize(name)
	    if !system("pkg-config --exists #{name}")
		raise NotFound.new(name)
	    end
	    
	    @name    = name
	    @version = `pkg-config --modversion #{name}`.chomp.strip
	    @actions = Hash.new
	    @variables = Hash.new
	end

	def self.define_action(action)
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

	def method_missing(varname, *args, &proc)
	    if args.empty?
		@variables[varname] ||= `pkg-config --variable=#{varname} #{name}`.chomp.strip
	    else
		super(varname, *args, &proc)
	    end
	end

        # Returns true if there is a package with this name
        def self.has_package?(name)
            enum_for(:each_package, name).find { true }
        end

        def self.each_package(regex = nil)
            `pkg-config --list-all`.chomp.split.
                each do |line|
                    line =~ /^([^\s]+)/
                    name = $1
                    if regex
                        if regex === name
                            yield(name)
                        end
                    else
                        yield(name)
                    end
                end
        end
    end
end

