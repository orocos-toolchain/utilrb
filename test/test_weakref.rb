require 'utilrb/test'
require 'utilrb/weakref'

class TC_WeakRef < Minitest::Test
    WeakRef = Utilrb::WeakRef

    def test_normal
        obj = Object.new
        ref = Utilrb::WeakRef.new(obj)
        assert_equal(obj, ref.get)
    end

    def test_initialize_validation
        ref = WeakRef.new(obj = Object.new)
        assert_raises(ArgumentError) { Utilrb::WeakRef.new(ref) }
    end
end

