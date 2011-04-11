module Marshal
    if defined? BasicObject
        class BlackHole < BasicObject
        end
    end

    class BlackHole
        class << self
            :name
        end

        def initialize(*args)
        end

        attr_reader :__content__
        def method_missing(*args)
        end
        def self._load(*args)
            hole = BlackHole.new
            hole.instance_variable_set(:@__content__, args)
        end

        def self.method_missing(*args)
        end
    end

    def self.load_with_missing_constants(str_or_io)
        if str_or_io.respond_to?(:tell)
            original_pos = str_or_io.tell
        end

        self.load(str_or_io)
    rescue Exception => e
        case e.message
        when /undefined class\/module ((?:\w+::)+)$/
            names = $1.split('::')
            missing = names.pop
            base = names.inject(Object) { |m, n| m.const_get(n) }
            base.const_set(missing, Module.new)

            if original_pos
                str_or_io.seek(original_pos)
            end
            retry
        when /undefined class\/module ((?:\w+::)+)(\w+)$/
            mod, klass   = $1, $2
            full_name = "#{mod}#{klass}"
            mod = mod.split('::').inject(Object) { |m, n| m.const_get(n) }

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

