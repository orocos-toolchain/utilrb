module Marshal
    class BlackHole
        class << self
            attr_reader :name
        end

        def initialize(*args)
        end

        def hash
            __id__
        end

        def eql?(obj)
            equal?(obj)
        end

        attr_reader :__content__
        def method_missing(*args)
            ::Kernel.puts args.inspect
            ::Kernel.puts ::Kernel.caller
        end
        def self._load(*args)
            hole = BlackHole.new
            hole.instance_variable_set(:@__content__, args)
        end

        def self.method_missing(*args, **options)
            BlackHole.new
        end
    end

    def self.load_with_missing_constants(str_or_io)
        if str_or_io.respond_to?(:tell)
            original_pos = str_or_io.tell
        end

        self.load(str_or_io)
    rescue Exception => e
        case e.message
        when /undefined class\/module ((?:\w+)(?:::\w+)*)(?:::)?$/
            full_name = $1
            path = $1.split('::')
            *path, klass = *path
            mod = path.inject(Object) { |m, n| m.const_get(n) }

            blackhole = Class.new(BlackHole) do
                @name = full_name
            end
            mod.const_set(klass, blackhole)

            if original_pos
                str_or_io.seek(original_pos)
            end
            retry
        end
        raise
    end
end

