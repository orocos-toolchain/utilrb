require 'utilrb/common'
module Kernel
    if Utilrb::RUBY_IS_19
    def with_module(*consts, &blk)
        slf = blk.binding.eval('self')
        l = if !block_given? && consts.last.respond_to?(:to_str)
                lambda { slf.instance_eval(consts.pop) }
            else
                lambda { slf.instance_eval(&blk) }
            end

        consts.reverse.inject(l) {|l, k| lambda { k.class_eval(&l) } }.call
    end
    else
    def with_module(*consts, &block)
        sandbox = Class.new do
            class << self
                attr_reader :main_object
                def method_missing(*args, &block)
                    main_object.send(*args, &block)
                end
            end
        end

        sandbox.instance_variable_set :@main_object, self
        context.each { |mod| sandbox.include(mod) }

        if !block_given? && consts.last.respond_to?(:to_str)
            sandbox.class_eval(consts.pop)
        else
            sandbox.class_eval(&blk)
        end
    end
    end
end

