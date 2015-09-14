$LOAD_PATH.unshift File.expand_path('lib', File.dirname(__FILE__))
require 'rake'

begin 
    require 'hoe'
    Hoe::plugin :yard
    Hoe::RUBY_FLAGS.gsub!(/-w/, '')

    hoe_spec = Hoe.spec 'utilrb' do
        developer "Sylvain Joyeux", "sylvain.joyeux@m4x.org"
        self.readme_file = 'README.rd'

        extra_deps <<
            ['facets', '>= 2.4.0'] <<
            ['rake',     '>= 0.9'] <<
            ["rake-compiler",   "~> 0.8.0"] <<
            ["hoe", ">= 3.7.1"] <<
            ["hoe-yard",   ">= 0.1.2"]

        extra_dev_deps <<
            ['flexmock', '>= 0.8.6'] <<
            ['debugger-ruby_core_source', '>= 0']

        licenses << 'BSD'

        spec_extras[:extensions] = FileList["ext/**/extconf.rb"]
    end

    require 'rubygems/package_task'
    Gem::PackageTask.new(hoe_spec.spec) do |pkg|
        pkg.need_zip = true
        pkg.need_tar = true
    end

    require 'rake/extensiontask'
    utilrb_task = Rake::ExtensionTask.new('utilrb', hoe_spec.spec) do |ext|
        ext.name = 'utilrb'
        ext.ext_dir = 'ext/utilrb'
        ext.lib_dir = 'lib/utilrb'
        ext.source_pattern ="*.{c,cc,cpp}"
    end

    Rake.clear_tasks(/^default$/)
    task :default => :compile

    task :docs => :yard
    task :redocs => :yard


rescue LoadError => e
    puts "'utilrb' cannot be build -- loading gem failed: #{e}"
end

task :full_test do
    ENV.delete_if { |name,val| name == "UTILRB_EXT_MODE" }
    system('testrb -I. test')
    ENV['UTILRB_EXT_MODE'] = 'yes'
    system('testrb -I. test')
end
