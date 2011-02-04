module Utilrb
    # Find configuration files within the pathes given 
    # by ROCK_CONFIG_PATH environment variable
    #
    class ConfigurationFinder

        # Find a file by searching through paths defined by an environment variable
        # and a given package directory. Package name is appended to all pathes found
        # in the environment
        # 
        # Returns the path to the file on success, otherwise nil
        def self.findWithEnv(filename, pkg_name, environment_search_path)
            if environment_search_path
                env_var = ENV[environment_search_path]
                # Extract search path from environment variable
                configuration_path = Array.new
                env_var.split(':').each do | path |
                    # Extract path and append package name folder
                    configuration_path << File.join(path.gsub(/:$/,''), pkg_name)
                end
            end

            if configuration_path == nil
                raise "ConfigurationFinder: Environment variable #{environment_search_path} is not set!\n" 
            else 
                configuration = search(filename, configuration_path)
            end

            configuration
        end

        # Search for a file within [ $ROCK_CONFIG_PATH ]/<packagename>/ 
        # Will not perform a recursive search   
        #
        # Returns the path to the file on success, otherwise nil
        def self.find(filename, pkg_name)
            findWithEnv(filename, pkg_name, 'ROCK_CONFIG_PATH')
        end

        # Search for a file only in the given search directories
        #
        # Returns the path to the file on success, otherwise nil
        def self.search(filename, search_dirs)
            search_dirs.each do |path|
                file = File.join(path,filename)
                if File.exist?(file)
                    return file
                end
            end
            return 
        end

        # Search for a file using the system id (<basename>_<id>) 
        # 
        # returns the configuration found in [ $ROCK_CONFIG_PATH ]/<basename>/<id>/, performs
        # a fallback search in <basename> and returns nil if no config could
        # be found 
        def self.findSystemConfig(filename, system_id)
            id_components = system_id.split('_')

            if(id_components.size != 2)
                raise "ConfigurationFinder: Invalid system identifier #{system_id} provided. " +
                      "Use <basename>_<id>"
            end

            base_pkg_name = id_components[0]
            id_pkg_name = File.join(base_pkg_name, id_components[1])
            system_config = find(filename, id_pkg_name)

            if !system_config
                system_config = find(filename, base_pkg_name)
            end

            system_config
        end
    end

end
