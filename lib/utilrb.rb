require 'utilrb/kernel/require'
require 'utilrb/logger'
module Utilrb
    extend Logger::Root('Utilrb', Logger::WARN)
end

require_dir(__FILE__, /yard|doc|rake|test/)
