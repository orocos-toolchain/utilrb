require 'utilrb/test'

require 'flexmock/minitest'
require 'set'
require 'enumerator'
require 'utilrb/module'

class TC_Module < Minitest::Test
    def test_include
        class_extension = Module.new do
            def tag; end
        end

        m = Module.new do
            const_set(:ClassExtension, class_extension)
        end
        
        m2 = Module.new { include m }
        assert(m2::ClassExtension.method_defined?(:tag))
        k = Class.new do
            include m2
        end
        assert(k.respond_to?(:tag))
    end

    Foo = 42

    def test_define_or_reuse
	mod = Module.new
        klass = Class.new

	new_mod = mod.define_or_reuse(:Foo) { klass.new }
        assert_kind_of(klass, new_mod)
	assert_equal(new_mod, mod.define_or_reuse(:Foo) { flunk("block called in #define_under") })

        # Now try with a constant that is widely available
	new_mod = mod.define_or_reuse('Signal') { klass.new }
        assert_kind_of(klass, new_mod)
	assert_equal(new_mod, mod.define_or_reuse('Signal') { flunk("block called in #define_under") })
    end

    def test_define_method_with_block
	FlexMock.use do |mock|
	    mock.should_receive(:called).once
	    block_obj = lambda { mock.called }
	    test_obj = self
	    method = lambda do |block, a, b|
		test_obj.assert_equal(a, 1)
		test_obj.assert_equal(b, 2)
		test_obj.assert_equal(block, block_obj)
		block_obj.call
	    end

	    klass = Class.new do
		define_method_with_block(:call, &method)
	    end
	    klass.new.call(1, 2, &block_obj)
	end
    end

    def test_attr_enumerable
        klass = Class.new do
            attr_enumerable(:mapped, :map) { Hash.new }
        end

        obj = klass.new
        obj.map[:a] = [10, 20]
        obj.map[:b] = 10
        assert_equal( [[:a, [10, 20]], [:b, 10]].to_set, obj.enum_for(:each_mapped).to_set )
        assert_equal( [10, 20], obj.enum_for(:each_mapped, :a).to_a )
    end

    def test_has_ancestor
        mod       = Module.new
        parent    = Class.new do
            include mod
        end
        child     = Class.new(parent)

        assert(child.has_ancestor?(parent))
        assert(child.has_ancestor?(mod))
        assert(parent.has_ancestor?(mod))

        assert(!parent.has_ancestor?(child))
    end

    def test_has_ancestor_for_singleton_classes
        mod       = Module.new
        parent    = Class.new do
            include mod
        end
        child     = Class.new(parent)
        n = Module.new

        assert(child.has_ancestor?(parent))
        assert(child.has_ancestor?(mod))
        assert(parent.has_ancestor?(mod))
        assert(!parent.has_ancestor?(child))

        obj_class = child.new.singleton_class
        obj_class.include(n = Module.new)
        assert obj_class.has_ancestor?(n)
    end

    def test_dsl_attribute_without_filter
        obj = Class.new do
            dsl_attribute :value
        end.new
        assert_same nil, obj.value
        assert_same obj, obj.value(10)
        assert_equal 10, obj.value
    end

    def test_dsl_attribute_with_filter
        obj = Class.new do
            dsl_attribute :value do |v|
                v * 2
            end
        end.new
        assert_same nil, obj.value
        assert_same obj, obj.value(10)
        assert_equal 20, obj.value
    end

    def test_singleton_class_p
        m = Module.new
        assert !m.singleton_class?
        s = Object.new.singleton_class
        assert s.singleton_class?
        assert s.singleton_class?
    end
end

