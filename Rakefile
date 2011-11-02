require 'rake'
require './lib/utilrb/common'
require './lib/utilrb/rake_common'

Utilrb::Rake.hoe do
    hoe_spec = Hoe.spec 'utilrb' do
        developer "Sylvain Joyeux", "sylvain.joyeux@m4x.org"
        extra_deps <<
            ['facets', '>= 2.4.0'] <<
            ['rake', '>= 0']

        extra_dev_deps <<
            ['flexmock', '>= 0.8.6']

        self.summary = 'Yet another Ruby toolkit'
        self.description = paragraphs_of('README.txt', 3..5).join("\n\n")
    end
    hoe_spec.spec.extensions << 'ext/extconf.rb'
    Rake.clear_tasks(/^default$/)
    Rake.clear_tasks(/publish_docs/)
end

task :default => :setup

desc "builds Utilrb's C extension"
task :setup do
    Dir.chdir("ext") do
	if !system("#{FileUtils::RUBY} extconf.rb") || !system("make")
	    raise "cannot build the C extension"
	end
    end
    FileUtils.ln_sf "../ext/utilrb_ext.so", "lib/utilrb_ext.so"
end

task :clean do
    puts "Cleaning extension in ext/"
    FileUtils.rm_f "lib/utilrb_ext.so"
    if File.file?(File.join('ext', 'Makefile'))
        Dir.chdir("ext") do
            system("make clean")
        end
    end
    FileUtils.rm_f "ext/Makefile"
    FileUtils.rm_f "lib/utilrb_ext.so"
end

task :full_test do
    ENV['UTILRB_EXT_MODE'] = 'no'
    system("testrb test/")
    ENV['UTILRB_EXT_MODE'] = 'yes'
    system("testrb test/")
end

