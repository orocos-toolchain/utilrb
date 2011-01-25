class Module
    if Utilrb::RUBY_IS_191 || Utilrb::RUBY_IS_19
    def const_defined_here?(name)
        const_defined?(name, false)
    end
    else
    def const_defined_here?(name)
        const_defined?(name)
    end
    end
end
