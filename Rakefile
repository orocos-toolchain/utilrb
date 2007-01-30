require 'hoe'
require './lib/utilrb/common'

Hoe.new('utilrb', Utilrb::VERSION) do |p|
    p.author = "Sylvain Joyeux"
    p.email = "sylvain.joyeux@m4x.org"

    p.summary = 'Yet another Ruby toolkit'
    p.description = p.paragraphs_of('README.txt', 3..6).join("\n\n")
    p.url         = p.paragraphs_of('README.txt', 0).first.split(/\n/)[1..-1]
    p.changes     = p.paragraphs_of('Changes.txt', 0..2).join("\n\n")

    p.extra_deps << 'facets'
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

