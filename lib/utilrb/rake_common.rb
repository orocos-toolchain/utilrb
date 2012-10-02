module Utilrb
    module Rake
        def self.hoe
            require 'hoe'
            yield

        rescue LoadError => e
            STDERR.puts "INFO: cannot load the Hoe gem. Distribution is disabled"
            STDERR.puts "INFO: error message is: #{e.message}"
            if ::Rake.application.options.trace
                puts e.backtrace.join("\n  ")
            end
        rescue Exception => e
            STDERR.puts "INFO: cannot load the Hoe gem, or Hoe fails. Distribution is disabled"
            STDERR.puts "INFO: error message is: #{e.message}"
            if ::Rake.application.options.trace
                puts e.backtrace.join("\n  ")
            end
        end

        def self.rdoc
            require 'rdoc/task'
            yield

        rescue LoadError => e
            STDERR.puts "INFO: cannot load RDoc, Documentation generation is disabled"
            STDERR.puts "INFO: error message is: #{e.message}"
            if ::Rake.application.options.trace
                puts e.backtrace.join("\n  ")
            end
        rescue Exception => e
            STDERR.puts "INFO: cannot load the RDoc gem, or RDoc failed to load. Documentation generation is disabled"
            STDERR.puts "INFO: error message is: #{e.message}"
            if ::Rake.application.options.trace
                puts e.backtrace.join("\n  ")
            end
        end
    end
end

