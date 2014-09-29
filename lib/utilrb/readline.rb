require 'utilrb/common'
Utilrb.require_ext("Readline#puts") do
    module Readline
        def self.puts(msg)
            print("#{msg}\n")
        end
    end
end

