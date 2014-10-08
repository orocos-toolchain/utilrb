require 'utilrb/test'
require 'flexmock/test_unit'
require 'tempfile'

require 'utilrb/kernel'

class TC_Kernel < Minitest::Test
    # Do NOT move this block. Some tests are checking the error lines in the
    # backtraces
    DSL_EXEC_BLOCK = Proc.new do
        real_method
        if KnownConstant != 10
            raise ArgumentError, "invalid constant value"
        end
        class Submod::Klass
            def my_method
            end
        end
        name('test')
        unknown_method()
    end

    def test_validate_options_passes_options_unmodified_if_they_are_valid_and_there_is_no_additional_defaults
        options = { :a => 1, :c => 2 }
        assert_equal options, validate_options(options, :a, :b, :c)
    end

    def test_validate_options_accepts_a_list_of_valid_options_as_array
        options = { :a => 1, :c => 2 }
        assert_equal options, validate_options(options, [:a, :b, :c])
    end

    def test_validate_options_raises_ArgumentError_if_given_an_unknown_option
        assert_raises(ArgumentError) { validate_options(Hash[c: 10], :b) }
    end

    def test_validate_options_does_not_add_options_without_default_to_the_returned_value
        assert_equal Hash.new, validate_options(Hash.new, :a, :b, :c)
    end

    def test_validate_options_sets_defaults
        assert_equal Hash[c: 10], validate_options(Hash.new, c: 10)
    end

    def test_validate_options_does_not_override_nil_by_the_default_value
        assert_equal Hash[c: nil], validate_options(Hash[c: nil], c: 10)
    end

    def test_validate_options_does_not_take_nil_as_a_default_value
        assert_equal Hash.new, validate_options(Hash.new, c: nil)
    end

    def test_validate_options_can_handle_string_keys
        assert_equal Hash[a: 10, c: nil], validate_options(Hash['c' => nil], 'a' => 10, :c =>  10)
    end

    def test_arity_of_methods
	object = Class.new do
	    def arity_1(a); end
	    def arity_any(*a); end
	    def arity_1_more(a, *b); end
	end.new

        # Should not raise
	check_arity(object.method(:arity_1), 1)
	assert_raises(ArgumentError) { check_arity(object.method(:arity_1), 0) }
	assert_raises(ArgumentError) { check_arity(object.method(:arity_1), 2) }

        # Should not raise
	check_arity(object.method(:arity_any), 0)
	check_arity(object.method(:arity_any), 2)

	check_arity(object.method(:arity_1_more), 1)
	assert_raises(ArgumentError) { check_arity(object.method(:arity_1_more), 0) }
	check_arity(object.method(:arity_1_more), 2)
    end

    def test_arity_of_blocks
        check_arity(Proc.new { bla }, 0)
        check_arity(Proc.new { bla }, 1)
        check_arity(Proc.new { bla }, 2)

        assert_raises(ArgumentError) { check_arity(Proc.new { |arg| bla }, 0) }
        check_arity(Proc.new { |arg| bla }, 1)
        assert_raises(ArgumentError) { check_arity(Proc.new { |arg| bla }, 2) }

        assert_raises(ArgumentError) { check_arity(Proc.new { |arg, *args| bla }, 0) }
        check_arity(Proc.new { |arg, *args| bla }, 1)
        check_arity(Proc.new { |arg, *args| bla }, 2)

        check_arity(Proc.new { |*args| bla }, 0)
        check_arity(Proc.new { |*args| bla }, 1)
        check_arity(Proc.new { |*args| bla }, 2)
    end

    def test_arity_of_lambdas
        check_arity(lambda { bla }, 0)
        assert_raises(ArgumentError) { check_arity(lambda { bla }, 1) }
        assert_raises(ArgumentError) { check_arity(lambda { bla }, 2) }

        assert_raises(ArgumentError) { check_arity(lambda { |arg| bla }, 0) }
        check_arity(lambda { |arg| bla }, 1)
        assert_raises(ArgumentError) { check_arity(lambda { |arg| bla }, 2) }

        assert_raises(ArgumentError) { check_arity(lambda { |arg, *args| bla }, 0) }
        check_arity(lambda { |arg, *args| bla }, 1)
        check_arity(lambda { |arg, *args| bla }, 2)

        check_arity(lambda { |*args| bla }, 0)
        check_arity(lambda { |*args| bla }, 1)
        check_arity(lambda { |*args| bla }, 2)
    end

    def test_with_module
        obj = Object.new
        c0, c1 = nil
        mod0 = Module.new do
            const_set(:Const, c0 = Object.new)
        end
        mod1 = Module.new do
            const_set(:Const, c1 = Object.new)
        end

        eval_string = "Const"
        const_val = obj.with_module(mod0, mod1, eval_string)
        assert_equal(c0, const_val)
        const_val = obj.with_module(mod1, mod0, eval_string)
        assert_equal(c1, const_val)

        const_val = obj.with_module(mod0, mod1) { Const }
        assert_equal(c0, const_val)
        const_val = obj.with_module(mod1, mod0) { Const }
        assert_equal(c1, const_val)

        assert_raises(NameError) { Const  }
    end

    module Mod
        module Submod
            class Klass
            end
        end

        const_set(:KnownConstant, 10)
    end

    def test_eval_dsl_file
        obj = Class.new do
            def real_method_called?; !!@real_method_called end
            def name(value)
            end
            def real_method
                @real_method_called = true
            end
        end.new

        Tempfile.open('test_eval_dsl_file') do |io|
            io.puts <<-EOD
            real_method
            if KnownConstant != 10
                raise ArgumentError, "invalid constant value"
            end
            class Submod::Klass
                def my_method
                end
            end
            name('test')
            unknown_method()
            EOD
            io.flush

            begin
                eval_dsl_file(io.path, obj, [], false)
                assert(obj.real_method_called?, "the block has not been evaluated")
                flunk("did not raise NameError for KnownConstant")
            rescue NameError => e
                assert e.message =~ /KnownConstant/, e.message
                assert e.backtrace.first =~ /#{io.path}:2/, "wrong backtrace when checking constant resolution: #{e.backtrace.join("\n")}"
            end

            begin
                eval_dsl_file(io.path, obj, [Mod], false)
                flunk("did not raise NoMethodError for unknown_method")
            rescue NoMethodError => e
                assert e.message =~ /unknown_method/
                assert e.backtrace.first =~ /#{io.path}:10/, "wrong backtrace when checking method resolution: #{e.backtrace.join("\n")}"
            end

            # instance_methods returns strings on 1.8 and symbols on 1.9. Conver
            # to strings to have the right assertion on both
            methods = Mod::Submod::Klass.instance_methods(false).map(&:to_s)
            assert(methods.include?('my_method'), "the 'class K' statement did not refer to the already defined class")
        end
    end

    if Utilrb::RUBY_IS_18
    def test_eval_dsl_file_does_not_allow_class_definition
        obj = Class.new do
            def real_method
                @real_method_called = true
            end
        end.new

        Tempfile.open('test_eval_dsl_file') do |io|
            io.puts <<-EOD
            class NewClass
            end
            EOD
            io.flush

            begin
                eval_dsl_file(io.path, obj, [], false)
                flunk("NewClass has been defined")
            rescue NameError => e
                assert e.message =~ /NewClass/, e.message
                assert e.backtrace.first =~ /#{io.path}:1/, "wrong backtrace when checking constant definition detection: #{e.backtrace[0]}, expected #{io.path}:1"
            end
        end
    end
    end

    def test_dsl_exec
        obj = Class.new do
            def real_method_called?; !!@real_method_called end
            def name(value)
            end
            def real_method
                @real_method_called = true
            end
        end.new

        begin
            dsl_exec(obj, [], false, &DSL_EXEC_BLOCK)
            assert(obj.real_method_called?, "the block has not been evaluated")
            flunk("did not raise NameError for KnownConstant")
        rescue NameError => e
            assert e.message =~ /KnownConstant/, e.message
            expected = "test_kernel.rb:12"
            assert e.backtrace.first =~ /#{expected}/, "wrong backtrace when checking constant resolution: #{e.backtrace.join("\n")}, expected #{expected}"
        end

        begin
            dsl_exec(obj, [Mod], false, &DSL_EXEC_BLOCK)
            flunk("did not raise NoMethodError for unknown_method")
        rescue NoMethodError => e
            assert e.message =~ /unknown_method/
            expected = "test_kernel.rb:20"
            assert e.backtrace.first =~ /#{expected}/, "wrong backtrace when checking method resolution: #{e.backtrace[0]}, expected #{expected}"
        end

        # instance_methods returns strings on 1.8 and symbols on 1.9. Conver
        # to strings to have the right assertion on both
        methods = Mod::Submod::Klass.instance_methods(false).map(&:to_s)
        assert(methods.include?('my_method'), "the 'class K' statement did not refer to the already defined class")
    end

    def test_load_dsl_file_loaded_features_behaviour
        eval_context = Class.new do
            attr_reader :real_method_call_count
            def initialize
                @real_method_call_count = 0
            end
            def real_method
                @real_method_call_count += 1
            end
        end

        Tempfile.open('test_eval_dsl_file') do |io|
            io.puts <<-EOD
            real_method
            EOD
            io.flush

            obj = eval_context.new
            assert(Kernel.load_dsl_file(io.path, obj, [], false))
            assert_equal(1, obj.real_method_call_count)
            assert($LOADED_FEATURES.include?(io.path))
            assert(!Kernel.load_dsl_file(io.path, obj, [], false))
            assert_equal(1, obj.real_method_call_count)

            $LOADED_FEATURES.delete(io.path)
        end

        Tempfile.open('test_eval_dsl_file') do |io|
            io.puts <<-EOD
            raise
            EOD
            io.flush

            obj = eval_context.new
            assert(!$LOADED_FEATURES.include?(io.path))
            assert_raises(RuntimeError) { Kernel.load_dsl_file(io.path, obj, [], false) }
            assert(!$LOADED_FEATURES.include?(io.path))
            assert_equal(0, obj.real_method_call_count)
        end
    end

    Utilrb.require_ext('is_singleton?') do
	def test_is_singleton
	    klass = Class.new
	    singl_klass = (class << klass; self end)
	    obj = klass.new

	    assert(!klass.is_singleton?)
	    assert(!obj.is_singleton?)
	    assert(singl_klass.is_singleton?)
	end
    end

    def test_poll
        flexmock(Kernel).should_receive(:sleep).with(2).twice
        counter = 0
        Kernel.poll(2) do
            counter += 1
            if counter > 2
                break
            end
        end
    end

    def test_wait_until
        flexmock(Kernel).should_receive(:sleep).with(2).twice
        counter = 0
        Kernel.wait_until(2) do
            counter += 1
            counter > 2
        end
    end

    def test_wait_while
        flexmock(Kernel).should_receive(:sleep).with(2).twice
        counter = 0
        Kernel.wait_while(2) do
            counter += 1
            counter <= 2
        end
    end
end

