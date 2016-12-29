# simplecov must be loaded FIRST. Only the files required after it gets loaded
# will be profiled !!!
if ENV['TEST_ENABLE_COVERAGE'] != '0'
    begin
        require 'simplecov'
        require 'coveralls'
        SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
            [SimpleCov::Formatter::HTMLFormatter,
             Coveralls::SimpleCov::Formatter]
        )
        SimpleCov.start do
            add_filter "/test/"
        end
    rescue LoadError
        require 'utilrb'
        Utilrb.warn "coverage is disabled because the 'simplecov' gem cannot be loaded"
    rescue Exception => e
        require 'utilrb'
        Utilrb.warn "coverage is disabled: #{e.message}"
    end
end

require 'utilrb'
require 'minitest/autorun'
require 'minitest/spec'

if ENV['TEST_ENABLE_PRY'] != '0'
    begin
        require 'pry'
    rescue Exception
        Utilrb.warn "debugging is disabled because the 'pry' gem cannot be loaded"
    end
end

BASE_TEST_DIR=File.expand_path('../../test', File.dirname(__FILE__))

module Utilrb
    # This module is the common setup for all tests
    #
    # It should be included in the toplevel describe blocks
    #
    # @example
    #   require 'dummyproject/test'
    #   describe Utilrb do
    #     include Utilrb::SelfTest
    #   end
    #
    module SelfTest
        def setup
            # Setup code for all the tests
        end

        def teardown
            super
            # Teardown code for all the tests
        end
    end
end

module Minitest
    class Test
        include Utilrb::SelfTest
    end
end

