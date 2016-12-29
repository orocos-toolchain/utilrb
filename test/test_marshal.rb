require 'utilrb/test'
require 'utilrb/marshal'

module MarshalLoadWithMissingConstantsEnv
end

describe Marshal do
    describe "#load_with_missing_constants" do
        after do
            Object.const_set :MarshalLoadWithMissingConstantsEnv, Module.new
        end

        it "resolves existing constants as expected" do
            MarshalLoadWithMissingConstantsEnv.const_set 'Test', (klass = Class.new)
            dumped = Marshal.dump(klass.new)
            obj = Marshal.load_with_missing_constants(dumped)
            assert_kind_of klass, obj
        end

        it "creates missing classes as needed" do
            MarshalLoadWithMissingConstantsEnv.const_set 'Test', (klass = Class.new)
            dumped = Marshal.dump(klass.new)
            Object.const_set :MarshalLoadWithMissingConstantsEnv, Module.new
            obj = Marshal.load_with_missing_constants(dumped)
            assert_same obj.class, MarshalLoadWithMissingConstantsEnv::Test
            assert_kind_of Marshal::BlackHole, obj
            assert_equal "MarshalLoadWithMissingConstantsEnv::Test", obj.class.name
        end

        it "resolves missing namespaces recursively" do
            MarshalLoadWithMissingConstantsEnv.const_set 'Test', (namespace = Module.new)
            MarshalLoadWithMissingConstantsEnv::Test.const_set 'Test', (klass = Class.new)
            dumped = Marshal.dump(klass.new)
            Object.const_set :MarshalLoadWithMissingConstantsEnv, Module.new
            obj = Marshal.load_with_missing_constants(dumped)

            blackhole_namespace = MarshalLoadWithMissingConstantsEnv::Test
            assert(blackhole_namespace < Marshal::BlackHole)
            assert_equal "MarshalLoadWithMissingConstantsEnv::Test", blackhole_namespace.name
            assert_same obj.class, blackhole_namespace::Test

            assert_kind_of Marshal::BlackHole, obj
            assert_equal "MarshalLoadWithMissingConstantsEnv::Test::Test", obj.class.name
        end
    end
end

