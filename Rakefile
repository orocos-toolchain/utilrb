require "bundler/gem_tasks"
require "rake/testtask"

require 'rake/extensiontask'
Rake::ExtensionTask.new('utilrb') do |ext|
    ext.name = 'utilrb'
    ext.ext_dir = 'ext/utilrb'
    ext.lib_dir = 'lib/utilrb'
    ext.source_pattern ="*.{c,cc,cpp}"
end

task :default => :compile

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/**/test_*.rb']
end

