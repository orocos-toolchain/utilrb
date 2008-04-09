require 'rake'
require 'rake/rdoctask'

# FIX: Hoe always calls rdoc with -d, and diagram generation fails here
class Rake::RDocTask
    alias __option_list__ option_list
    def option_list
	options = __option_list__
	options.delete("-d")
	options
    end
end

require './lib/utilrb/common'

begin
    require 'hoe'
    Hoe.new('utilrb', Utilrb::VERSION) do |p|
        p.author = "Sylvain Joyeux"
        p.email = "sylvain.joyeux@m4x.org"

        p.summary = 'Yet another Ruby toolkit'
        p.description = p.paragraphs_of('README.txt', 3..6).join("\n\n")
        p.url         = p.paragraphs_of('README.txt', 0).first.split(/\n/)[1..-1]
        p.changes     = p.paragraphs_of('History.txt', 0..1).join("\n\n")

        p.extra_deps << 'facets'
        p.rdoc_pattern = /(ext\/.*cc$|lib)|txt/
    end
rescue LoadError
    puts "cannot load the Hoe gem, distribution is disabled"
end

desc "builds Utilrb's C extension"
task :setup do
    Dir.chdir("ext") do
	if !system("ruby extconf.rb") || !system("make")
	    raise "cannot build the C extension"
	end
    end
    FileUtils.ln_sf "../../ext/faster.so", "lib/utilrb/faster.so"
end

task :full_test do
    ENV['UTILRB_FASTER_MODE'] = 'no'
    system("testrb test/")
    ENV['UTILRB_FASTER_MODE'] = 'yes'
    system("testrb test/")
end

task :rcov_test do
    Dir.chdir('test') do 
	if !File.directory?('../rcov')
	    File.mkdir('../rcov')
	end
	File.open("../rcov/index.html", "w") do |index|
	    index.puts <<-EOF
		<!DOCTYPE html PUBLIC 
		    "-//W3C//DTD XHTML 1.0 Transitional//EN" 
		    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
		<body>
	    EOF

	    Dir.glob('test_*.rb').each do |path|
		puts "\n" * 4 + "=" * 5 + " #{path} " + "=" * 5 + "\n"
		basename = File.basename(path, '.rb')
		system("rcov --replace-progname -o ../rcov/#{basename} #{path}")
		index.puts "<div class=\"test\"><a href=\"#{basename}/index.html\">#{basename}</a></div>"
	    end
	    index.puts "</body>"
	end
    end
end

