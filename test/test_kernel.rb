# This block MUST stay at the very beginning of the file
#
# The tests refer to the line numbers, so putting it anywhere else gives
# headaches
TC_Kernel_DSL_EXEC_BLOCK = Proc.new do
    real_method
    if KnownConstant != 10
        raise ArgumentError, "invalid constant value"
    end
    class Submod::Klass
        def my_method
        end
    end
    name('test')
    unknown_method
end

require 'test_config'
require 'flexmock'
require 'tempfile'

require 'utilrb/kernel/options'
require 'utilrb/kernel/arity'
require 'utilrb/kernel/swap'
require 'utilrb/kernel/with_module'
require 'utilrb/kernel/load_dsl_file'
require 'utilrb/object/is_singleton_p'

class TC_Kernel < Test::Unit::TestCase
    DSL_EXEC_BLOCK = TC_Kernel_DSL_EXEC_BLOCK

    def test_validate_options
        valid_options   = [ :a, :b, :c ]
        valid_test      = { :a => 1, :c => 2 }
        invalid_test    = { :k => nil }
        assert_nothing_raised(ArgumentError) { validate_options(valid_test, valid_options) }
        assert_raise(ArgumentError) { validate_options(invalid_test, valid_options) }

        check_array = validate_options( valid_test, valid_options )
        assert_equal( valid_test, check_array )
        check_empty_array = validate_options( nil, valid_options )
        assert_equal( {}, check_empty_array )

	# Check default value settings
        default_values = { :a => nil, :b => nil, :c => nil, :d => 15, :e => [] }
        new_options = nil
        assert_nothing_raised(ArgumentError) { new_options = validate_options(valid_test, default_values) }
	assert_equal(15, new_options[:d])
	assert_equal([], new_options[:e])
        assert( !new_options.has_key?(:b) )
    end

    def test_arity
	object = Class.new do
	    def arity_1(a); end
	    def arity_any(*a); end
	    def arity_1_more(a, *b); end
	end.new

	assert_nothing_raised { check_arity(object.method(:arity_1), 1) }
	assert_raises(ArgumentError) { check_arity(object.method(:arity_1), 0) }
	assert_raises(ArgumentError) { check_arity(object.method(:arity_1), 2) }

	assert_nothing_raised { check_arity(object.method(:arity_any), 0) }
	assert_nothing_raised { check_arity(object.method(:arity_any), 2) }

	assert_nothing_raised { check_arity(object.method(:arity_1_more), 1) }
	assert_raises(ArgumentError) { check_arity(object.method(:arity_1_more), 0) }
	assert_nothing_raised { check_arity(object.method(:arity_1_more), 2) }
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
            unknown_method
            EOD
            io.flush

            begin
                eval_dsl_file(io.path, obj, [], false)
                assert(obj.real_method_called?, "the block has not been evaluated")
                flunk("did not raise NameError for KnownConstant")
            rescue NameError => e
                assert e.message =~ /KnownConstant/, e.message

                backtrace = e.backtrace.dup
                while backtrace.first =~ /const_missing/
                    backtrace.shift
                end
                assert backtrace.first =~ /#{io.path}:2/, "wrong backtrace when checking constant resolution: #{backtrace.join("\n")}"
            end

            begin
                eval_dsl_file(io.path, obj, [Mod], false)
                flunk("did not raise NoMethodError for unknown_method")
            rescue NoMethodError => e
                assert e.message =~ /unknown_method/

                backtrace = e.backtrace.dup
                while backtrace.first =~ /method_missing/
                    backtrace.shift
                end
                assert backtrace.first =~ /#{io.path}:10/, "wrong backtrace when checking method resolution: #{backtrace.join("\n")}"
            end

            # instance_methods returns strings on 1.8 and symbols on 1.9. Conver
            # to strings to have the right assertion on both
            methods = Mod::Submod::Klass.instance_methods(false).map(&:to_s)
            assert(methods.include?('my_method'), "the 'class K' statement did not refer to the already defined class")
        end
    end

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
                eval_dsl_file(io.path, obj, [], true)
                flunk("NewClass has been defined")
            rescue NameError => e
                assert e.message =~ /NewClass/, e.message
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
            expected = "test_kernel.rb:7"

            backtrace = e.backtrace.dup
            while backtrace.first =~ /const_missing/
                backtrace.shift
            end
            assert backtrace.first =~ /#{expected}/, "wrong backtrace when checking constant resolution: #{backtrace[0]}, expected #{expected}"
        end

        begin
            dsl_exec(obj, [Mod], false, &DSL_EXEC_BLOCK)
            flunk("did not raise NoMethodError for unknown_method")
        rescue NoMethodError => e
            assert e.message =~ /unknown_method/
            expected = "test_kernel.rb:15"

            backtrace = e.backtrace.dup
            while backtrace.first =~ /method_missing/
                backtrace.shift
            end
            assert backtrace.first =~ /#{expected}/, "wrong backtrace when checking method resolution: #{backtrace[0]}, expected #{expected}"
        end

        # instance_methods returns strings on 1.8 and symbols on 1.9. Conver
        # to strings to have the right assertion on both
        methods = Mod::Submod::Klass.instance_methods(false).map(&:to_s)
        assert(methods.include?('my_method'), "the 'class K' statement did not refer to the already defined class")
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
end

