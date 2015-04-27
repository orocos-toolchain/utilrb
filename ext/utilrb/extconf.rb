require 'mkmf'

CONFIG['LDSHARED'].gsub! '$(CC)', "$(CXX)"
if try_link("int main() { }", "-module")
    $LDFLAGS += " -module"
end

if RUBY_VERSION < "1.9"
    $CFLAGS += " -DRUBY_IS_18"
    puts "not building with core source"
    create_makefile("utilrb/utilrb")
else
    begin
        require 'debugger/ruby_core_source'
        hdrs = lambda { try_compile("#include <vm_core.h>") }
        $CFLAGS += " -DHAS_RUBY_SOURCE"
        Debugger::RubyCoreSource.create_makefile_with_core(hdrs, "utilrb/utilrb")
    rescue Exception
        $CFLAGS.gsub!(/ -DHAS_RUBY_SOURCE/, '')
        puts "not building with core source"
        create_makefile("utilrb/utilrb")
    end
end

## WORKAROUND a problem with mkmf.rb
# It seems that the newest version do define an 'install' target. However, that
# install target tries to install in the system directories
#
# The issue is that RubyGems *does* call make install. Ergo, gem install utilrb
# is broken right now
#lines = File.readlines("Makefile")
#lines.delete_if { |l| l =~ /^install:/ }
#lines << "install:"
#File.open("Makefile", 'w') do |io|
#      io.write lines.join("\n")
#end

