require 'utilrb/kernel/options'

module Utilrb
    DOC_MODE =
        begin
            require 'yard'
            require 'yard/rake/yardoc_task'
            'yard'
        rescue LoadError
            begin
                require 'rdoc/task'
                'rdoc-new'
            rescue LoadError
                begin
                    require 'rake/rdoctask'
                    'rdoc-old'
                rescue LoadError
                end
            end
        end

    def self.doc(target, options = Hash.new)
        options = Kernel.validate_options options,
            :include => [Dir.pwd],
            :exclude => [],
            :target_dir => 'doc',
            :title => ''

        case DOC_MODE
        when 'yard'
            task = YARD::Rake::YardocTask.new(target)
            task.files.concat(options[:include])
            task.options << '--title' << options[:title] << '--output-dir' << options[:target_dir]
        when /rdoc/
            klass = if DOC_MODE == 'rdoc-new'
                        Rdoc::Task
                    else
                        Rake::RdocTask
                    end
            task = klass.new(target)
            task.rdoc_files.include(*options[:include])
            task.rdoc_files.exclude(*options[:exclude])
            task.title = options[:title]
            task.rdoc_dir = options[:target_dir]
        end
    end
end
