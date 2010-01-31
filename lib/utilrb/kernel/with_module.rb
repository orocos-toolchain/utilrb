if RUBY_IS_19
module Kernel
    def with_module(*consts, &blk)
        slf = blk.binding.eval('self')
        l = lambda { slf.instance_eval(&blk) }
        consts.reverse.inject(l) {|l, k| lambda { k.class_eval(&l) } }.call
    end
end
end

