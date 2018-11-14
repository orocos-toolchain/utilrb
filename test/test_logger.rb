require 'utilrb/test'
require 'utilrb/logger'
require 'flexmock/minitest'

class TC_Logger < Minitest::Test
    module Root
        extend Logger::Root('TC_Logger', Logger::INFO)

        module Child
            extend Logger::Hierarchy
        end
        class Klass
            extend Logger::Hierarchy
        end
    end

    def setup
        Root.reset_own_logger
        HierarchyTest.reset_own_logger
        HierarchyTest.logger = "root_logger"
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

    def test_logger_hierarchy_on_anonymous_classes
        child = Class.new(Root::Klass)
        assert_same Root.logger, child.logger
        assert child.respond_to?(:warn)
    end

    def test_logger_hierarchy_on_instances_of_anonymous_classes
        child_m = Class.new(Root::Klass) do
            include Logger::Hierarchy
        end
        child = child_m.new
        assert_same Root.logger, child.logger
        assert child.respond_to?(:warn)
    end

    def test_logger_hierarchy_on_classes_that_have_almost_a_class_name
        child_m = Class.new(Root::Klass) do
            include Logger::Hierarchy
            def self.name
                "A::NonExistent::Constant::Name"
            end
        end
        child = child_m.new
        assert_same Root.logger, child.logger
        assert child.respond_to?(:warn)
    end

    def test_logger_hierarch_make_own
        child = Root::Child
        assert_same Root.logger, child.logger

        child.make_own_logger('child', Logger::DEBUG)
        refute_same Root.logger, child.logger
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
        refute_same Root.logger, child.logger
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


    module HierarchyTest
        extend Logger.Root('test', Logger::INFO)
        self.logger = 'root_logger'
        class HierarchyTest
            extend Logger::Hierarchy
            extend Logger::Forward
        end

        module A
            extend Logger::Hierarchy
            extend Logger::Forward

            class B
                extend Logger::Hierarchy
                include Logger::Hierarchy
            end
        end
    end

    module HierarchyTestForSubclass
        def self.logger; "other_logger" end
        class HierarchyTest < HierarchyTest::HierarchyTest
        end
    end

    module NotALoggingModule
        class HierarchyTest < HierarchyTest::HierarchyTest
        end
        class NoLogger
        end
    end

    def test_hierarchy_can_resolve_parent_logger_with_identical_name
        assert_equal "root_logger", HierarchyTest::HierarchyTest.logger
    end
    def test_hierarchy_can_resolve_parent_logger_in_subclasses_where_the_subclass_parent_module_is_not_providing_a_logger
        assert_equal "root_logger", NotALoggingModule::HierarchyTest.logger
    end
    def test_hierarchy_resolution_starts_at_superclass_if_enclosing_module_does_not_provide_a_logger
        flexmock(HierarchyTest::HierarchyTest).should_receive(logger: "specific_class_logger")
        assert_equal "specific_class_logger", NotALoggingModule::HierarchyTest.logger
    end
    def test_hierarchy_resolves_the_parent_module_first_even_in_subclasses
        assert_equal "other_logger", HierarchyTestForSubclass::HierarchyTest.logger
    end
    def test_hierarchy_raises_if_no_parent_logger_can_be_found
        assert_raises(Logger::Hierarchy::NoParentLogger) { NotALoggingModule::NoLogger.extend Logger::Hierarchy }
    end

    module RootModule
    end
    def test_hierarchy_raises_if_hierarchy_is_called_on_a_root_module
        assert_raises(Logger::Hierarchy::NoParentLogger) { RootModule.extend Logger::Hierarchy }
    end

    def test_hierarchy_reset_default_logger_deregisters_the_logger_from_its_parent
        HierarchyTest::HierarchyTest.logger
        HierarchyTest::HierarchyTest.reset_default_logger
        assert_equal [], HierarchyTest.each_log_child.to_a
    end
    def test_hierarchy_reset_default_logger_resets_the_list_of_children
        HierarchyTest.reset_default_logger
        assert_equal [], HierarchyTest.each_log_child.to_a
    end

    def test_instance_resolves_to_class_logger
        klass = Class.new(HierarchyTest::HierarchyTest)
        klass.send(:include, Logger::Hierarchy)
        obj = klass.new
        assert_equal "root_logger", obj.logger
    end
    def test_instance_resolves_to_own_logger_if_set
        a_logger = HierarchyTest::A.make_own_logger
        assert_same a_logger, HierarchyTest::A::B.logger
    end

    def test_forwards_log_level_to_level
        obj = Class.new do
            attr_accessor :logger
            include Logger::Forward
        end.new
        obj.logger = (logger_mock = flexmock)
        logger_mock.should_receive(:level=).with(10)
        logger_mock.should_receive(:level).and_return(10)
        obj.log_level = 10
        assert_equal 10, obj.log_level
    end
end
