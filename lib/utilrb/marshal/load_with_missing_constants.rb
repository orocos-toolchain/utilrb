module Marshal
    def self.load_with_missing_constants(str_or_io)
        self.load(str_or_io)
    rescue Exception => e
        case e.message
        when /undefined class\/module ((?:\w+::)+)$/
            names = $1.split('::')
            missing = names.pop
            base = names.inject(Object) { |m, n| m.const_get(n) }
            base.const_set(missing, Module.new)
            retry
        when /undefined class\/module ((?:\w+::)+)(\w+)$/
            mod, klass   = $1, $2
            full_name = "#{mod}#{klass}"
            mod = mod.split('::').inject(Object) { |m, n| m.const_get(n) }

            blackhole = Class.new(BlackHole) do
                @name = full_name
            end
            mod.const_set(klass, blackhole)
            retry
        end
        raise
    end
end

