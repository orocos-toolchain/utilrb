require 'test_config'
require 'utilrb/logger'

class TC_Logger < Test::Unit::TestCase
    module Root
        extend Logger::Root('TC_Logger', Logger::INFO)

        module Child
            extend Logger::Hierarchy
        end
    end

    def teardown
        Root::Child.reset_own_logger
    end

    def test_logger_root
        assert Root.respond_to?(:logger)
        assert Root.logger
        assert_equal Logger::INFO, Root.logger.level
        assert_equal 'TC_Logger', Root.logger.progname

        assert Root.respond_to?(:warn)
    end

    def test_logger_hierarchy
        child = Root::Child
        assert child.respond_to?(:logger)
        assert child.logger
        assert_same Root.logger, child.logger
        assert child.respond_to?(:warn)
    end

    def test_logger_hierarch_make_own
        child = Root::Child
        assert_same Root.logger, child.logger

        child.make_own_logger('child', Logger::DEBUG)
        assert_not_same Root.logger, child.logger
        assert_equal "child", child.logger.progname
        assert_equal Logger::DEBUG, child.logger.level
        assert_equal "TC_Logger", Root.logger.progname
        assert_equal Logger::INFO, Root.logger.level

        assert child.has_own_logger?
    end

    def test_logger_hierarch_reset_own
        child = Root::Child
        child.make_own_logger('child', Logger::DEBUG)
        assert_not_same Root.logger, child.logger
        child.reset_own_logger
        test_logger_hierarchy
    end
end
