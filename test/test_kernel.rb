require 'test_config'
require 'flexmock'
require 'tempfile'

require 'utilrb/kernel/options'
require 'utilrb/kernel/arity'
require 'utilrb/kernel/swap'
require 'utilrb/kernel/with_module'
require 'utilrb/kernel/load_dsl_file'

class TC_Kernel < Test::Unit::TestCase
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
        c = nil
        mod = Module.new do
            const_set(:Const, c = Object.new)
        end

        eval_string = "Const"
        const_val = obj.with_module(mod, eval_string)
        assert_equal(c, const_val)

        const_val = obj.with_module(mod) do
            Const
        end
        assert_equal(c, const_val)

        assert_raises(NameError) { Const  }
    end

    def test_eval_dsl_file
        mod = Module.new do
            const_set(:KnownConstant, 10)
        end

        obj = Class.new do
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
            unknown_method
            EOD
            io.flush

            begin
                eval_dsl_file(io.path, obj, [], false)
                flunk("did not raise NameError for KnownConstant")
            rescue NameError => e
                assert e.message =~ /KnownConstant/
                assert e.backtrace.first =~ /#{io.path}:2/
            end

            begin
                eval_dsl_file(io.path, obj, [mod], false)
                flunk("did not raise NoMethodError for unknown_method")
            rescue NoMethodError => e
                assert e.message =~ /unknown_method/
                assert e.backtrace.first =~ /#{io.path}:5/
            end
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

    Utilrb.require_ext('test_swap') do
	def test_swap
	    obj = Array.new
	    Kernel.swap!(obj, Hash.new)
	    assert_instance_of Hash, obj

	    GC.start
	end
    end
end

