require 'mkmf'

if RUBY_VERSION >= "1.9"
    $CFLAGS += " -DRUBY_IS_19"
end

if ENV['RUBY_SOURCE_DIR']
    $CFLAGS += " -DHAS_RUBY_SOURCE -I#{ENV['RUBY_SOURCE_DIR']}"
end

if try_link("int main() { }", "-module")
    $LDFLAGS += " -module"
end
create_makefile("utilrb_ext")

## WORKAROUND a problem with mkmf.rb
# It seems that the newest version do define an 'install' target. However, that
# install target tries to install in the system directories
#
# The issue is that RubyGems *does* call make install. Ergo, gem install utilrb
# is broken right now
lines = File.readlines("Makefile")
lines.delete_if { |l| l =~ /^install:/ }
lines << "install:"
File.open("Makefile", 'w') do |io|
      io.write lines.join("\n")
end

