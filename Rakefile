require 'rake'
require './lib/utilrb/common'

begin
    require 'hoe'

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

rescue Exception => e
    if e.message !~ /\.rubyforge/
        STDERR.puts "WARN: cannot load the Hoe gem, or Hoe fails. Publishing tasks are disabled"
        STDERR.puts "WARN: error message is: #{e.message}"
    end
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

task 'publish_docs' => 'redocs' do
    if !system('./update_github')
        raise "cannot update the gh-pages branch for GitHub"
    end
    if !system('git', 'push', 'github', '+gh-pages')
        raise "cannot push the documentation"
    end
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

