require 'rake/rdoctask'

Rake::RDocTask.new("rdoc") do |rdoc|
  rdoc.options << "--inline-source"
  rdoc.rdoc_dir = 'html'
  rdoc.title    = "Utilrb"
  rdoc.rdoc_files.include('lib/**/*.rb', 'doc/**/*.rdoc')
  rdoc.rdoc_files.exclude('doc/**/*_attrs.rdoc')
end

task :test do
    ENV['UTILRB_FASTER_MODE'] = 'no'
    system("testrb test/")
    ENV['UTILRB_FASTER_MODE'] = 'yes'
    system("testrb test/")
end

task :test_rcov do
    Dir.chdir('test') do 
	if !File.directory?('../rcov')
	    File.mkdir('../rcov')
	end
	File.open("../rcov/index.html", "w") do |index|
	    index.puts <<-EOF
		<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
		<body>
	    EOF

	    Dir.glob('test_*.rb').each do |path|
		puts "\n" * 4 + "=" * 5 + " #{path} " + "=" * 5 + "\n"
		basename = File.basename(path, '.rb')
		system("rcov -o ../rcov/#{basename} #{path}")
		index.puts "<div class=\"test\"><a href=\"#{basename}/index.html\">#{basename}</a></div>"
	    end
	    index.puts "</body>"
	end
    end
end

