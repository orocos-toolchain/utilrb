require './test_config'
require 'utilrb/logger'
require 'flexmock/test_unit'

class TC_Logger < Test::Unit::TestCase
    module Root
        extend Logger::Root('TC_Logger', Logger::INFO)

        module Child
            extend Logger::Hierarchy
        end
    end

    def teardown
        Root.reset_own_logger
        Root::Child.reset_own_logger
        super
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

    def test_logger_hierarch_make_own_propagates_to_children
        child = Root::Child
        assert_same Root.logger, child.logger
        Root.make_own_logger('root', Logger::DEBUG)
        assert_same Root.logger, child.logger
    end

    def test_logger_hierarch_reset_own
        child = Root::Child
        child.make_own_logger('child', Logger::DEBUG)
        assert_not_same Root.logger, child.logger
        child.reset_own_logger
        test_logger_hierarchy
    end

    def test_logger_nest_size
        logger = Logger.new(StringIO.new)
        logger.formatter = flexmock
        logger.formatter.should_receive(:call).with(any, any, any, "msg0").once.ordered
        logger.formatter.should_receive(:call).with(any, any, any, "   msg1").once.ordered
        logger.formatter.should_receive(:call).with(any, any, any, " msg2").once.ordered
        logger.formatter.should_receive(:call).with(any, any, any, "msg3").once.ordered
        logger.nest_size = 0
        logger.warn("msg0")
        logger.nest_size = 3
        logger.warn("msg1")
        logger.nest_size = 1
        logger.warn("msg2")
        logger.nest_size = 0
        logger.warn("msg3")
    end

    def test_logger_nest
        logger = Logger.new(StringIO.new)
        logger.formatter = flexmock
        logger.formatter.should_receive(:call).with(any, any, any, "msg0").once.ordered
        logger.formatter.should_receive(:call).with(any, any, any, "  msg1").once.ordered
        logger.formatter.should_receive(:call).with(any, any, any, "   msg2").once.ordered
        logger.formatter.should_receive(:call).with(any, any, any, "  msg3").once.ordered
        logger.formatter.should_receive(:call).with(any, any, any, "msg4").once.ordered
        logger.warn("msg0")
        logger.nest(2) do
            logger.warn("msg1")
            logger.nest(1) do
                logger.warn("msg2")
            end
            logger.warn("msg3")
        end
        logger.warn("msg4")
    end

    def test_logger_io
        logger = flexmock
        io = Logger::LoggerIO.new(logger, :uncommon_level)

        logger.should_receive(:uncommon_level).with("msg0").once.ordered
        logger.should_receive(:uncommon_level).with("msg1 msg2").once.ordered
        io.puts "msg0"
        io.print "msg1"
        io.puts " msg2"
    end
end
