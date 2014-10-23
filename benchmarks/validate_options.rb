require 'benchmark'
require 'utilrb/kernel/options'

options = Hash[
    test: 10,
    other_test: 20]

TIMES = 100_000

def validate(options)
    Kernel.validate_options options, :accept_opaques => false,
        :accept_pointers => false,
        :merge_skip_copy => true,
        :remove_trailing_skips => true
end

def validate_with_new_style_hash(options)
    Kernel.validate_options options, accept_opaques: false,
        accept_pointers: false,
        merge_skip_copy: true,
        remove_trailing_skips: true
end

def validate_with_keyword_arguments(accept_opaques: false,
                                    accept_pointers: false,
                                    merge_skip_copy: true,
                                    remove_trailing_skips: true)
    Hash[accept_opaques: accept_opaques,
         accept_pointers: accept_pointers,
         merge_skip_copy: merge_skip_copy,
         remove_trailing_skips: remove_trailing_skips]
end

Benchmark.bm do |x|
    x.report("with empty options") do
        TIMES.times do
            validate(Hash.new)
        end
    end
    x.report("with empty options and new-style hash") do
        TIMES.times do
            validate_with_new_style_hash(Hash.new)
        end
    end
    x.report("with empty options and keyword arguments") do
        TIMES.times do
            validate_with_keyword_arguments(accept_opaques: false,
                accept_pointers: false,
                merge_skip_copy: true,
                remove_trailing_skips: true)
        end
    end
    x.report("with all options set") do
        options = Hash[]
        TIMES.times do
            validate(:accept_opaques => false,
                     :accept_pointers => false,
                     :merge_skip_copy => true,
                     :remove_trailing_skips => true)
        end
    end
    x.report("with all options set and new-style hash") do
        TIMES.times do
            validate_with_new_style_hash(accept_opaques: false,
                     accept_pointers: false,
                     merge_skip_copy: true,
                     remove_trailing_skips: true)
        end
    end
    x.report("with all options set and keyword arguments") do
        TIMES.times do
            validate_with_keyword_arguments(accept_opaques: false,
                     accept_pointers: false,
                     merge_skip_copy: true,
                     remove_trailing_skips: true)
        end
    end
end

