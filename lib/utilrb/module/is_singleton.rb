class Module
    if !method_defined?(:singleton_class?)
        require 'utilrb/utilrb'
    end

    alias :is_singleton? :singleton_class?
end
