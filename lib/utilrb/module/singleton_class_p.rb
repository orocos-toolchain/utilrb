class Module
    if !method_defined?(:singleton_class?)
        # It so happens that this method to determine whether a class is a
        # singleton class is valid for ruby 2.0 and breaks on 2.1 ... However
        # (!) on 2.1 singleton_class? is defined
        def singleton_class?
            if instance_variable_defined?(:@__utilrb_singleton_class)
                @__utilrb_singleton_class
            else
                @__utilrb_singleton_class = (ancestors.first == self)
            end
        end
    end
end
