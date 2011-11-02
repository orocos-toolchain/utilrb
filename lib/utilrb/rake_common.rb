module Utilrb
    module Rake
        def self.if_hoe_available
            require 'hoe'

            yield

        rescue Exception => e
            if e.message !~ /\.rubyforge/
                STDERR.puts "cannot load the Hoe gem, or Hoe fails. Publishing tasks are disabled"
                STDERR.puts "error message is: #{e.message}"
            end
        end
    end
end

