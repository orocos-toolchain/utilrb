# simplecov must be loaded FIRST. Only the files required after it gets loaded
# will be profiled !!!
if ENV['TEST_ENABLE_COVERAGE'] == '1'
    begin
        require 'simplecov'
        SimpleCov.start
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
require 'flexmock/test_unit'

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
        if defined? FlexMock
            include FlexMock::ArgumentTypes
            include FlexMock::MockContainer
        end

        def setup
            # Setup code for all the tests
        end

        def teardown
            if defined? FlexMock
                flexmock_teardown
            end
            super
            # Teardown code for all the tests
        end
    end
end

module Minitest
    class Spec
        include Utilrb::SelfTest
    end
    class Test
        include Utilrb::SelfTest
    end
end

