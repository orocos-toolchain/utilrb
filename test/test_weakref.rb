if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'rbx'
    return
end

require 'test/unit/testcase'
require 'utilrb/weakref'

Utilrb.require_ext('TC_WeakRef') do
    class TC_WeakRef < Test::Unit::TestCase
        WeakRef = Utilrb::WeakRef
        def test_normal
            obj = Object.new
            ref = Utilrb::WeakRef.new(obj)

            assert_equal(obj, ref.get)
        end

        def test_initialize_validation
            assert_raises(ArgumentError) { Utilrb::WeakRef.new(nil) }
            assert_raises(ArgumentError) { Utilrb::WeakRef.new(5) }

            ref = WeakRef.new(Object.new)
            assert_raises(ArgumentError) { Utilrb::WeakRef.new(ref) }
        end

        def create_deep_pair(lvl)
            if lvl == 0
                100.times do
                    obj = Object.new
                    WeakRef.new(obj)
                    obj = nil
                end
            else
                create_deep_pair(lvl - 1)
            end
        end

        def create_deep_ref(lvl)
            if lvl == 0
                obj = Object.new
                refs = (1..100).map { WeakRef.new(obj) }
                return refs, obj.object_id
            else
                create_deep_ref(lvl - 1)
            end
        end

        def create_deep_obj(lvl)
            if lvl == 0
                ref = WeakRef.new(obj = Object.new)
                return obj, ref.object_id
            else
                create_deep_obj(lvl - 1)
            end
        end

        def test_finalized_objects
            refs, obj_id = create_deep_ref(100)
            create_deep_ref(200) # erase the stack ...
            GC.start
            for ref in refs
                assert_raises(WeakRef::RefError) { ref.get }
            end
            assert_equal(nil, WeakRef.refcount(obj_id))
        end

        def test_finalized_refs
            obj, ref_id = create_deep_obj(100)
            create_deep_ref(100) # erase the stack ...
            GC.start
            assert_raises(RangeError) do
                ref = ObjectSpace._id2ref(ref_id)
                if !ref.kind_of?(WeakRef)
                    raise RangeError
                end
            end
        end

        def test_finalization_ordering_crash
            create_deep_pair(100)
            GC.start
        end
    end
end

