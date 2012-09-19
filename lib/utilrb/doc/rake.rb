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

    def self.doc(target = 'docs', options = Hash.new)
        options = Kernel.validate_options options,
            :include => [File.join('lib', '**', '*.rb'), File.join('ext', '**', '*.cc')],
            :exclude => [],
            :target_dir => 'doc',
            :title => '',
            :plugins => []

        case DOC_MODE
        when 'yard'
            task = YARD::Rake::YardocTask.new(target)
            task.files.concat(options[:include])
            task.options << '--title' << options[:title] << '--output-dir' << options[:target_dir]
            options[:plugins].each do |plugin_name|
                require "#{plugin_name}/yard"
            end
        when /rdoc/
            klass = if DOC_MODE == 'rdoc-new'
                        RDoc::Task
                    else
                        ::Rake::RDocTask
                    end
            task = klass.new(target)
            task.rdoc_files.include(*options[:include])
            task.rdoc_files.exclude(*options[:exclude])
            task.title = options[:title]
            task.rdoc_dir = File.expand_path(options[:target_dir])
        end
    end
end
