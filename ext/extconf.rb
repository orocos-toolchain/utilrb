require 'mkmf'

CONFIG['CC'] = "g++"
if defined?(RUBY_ENGINE) && RUBY_ENGINE == "rbx"
    $CFLAGS += " -DRUBY_IS_RBX"
end

if RUBY_VERSION >= "1.9"
    $CFLAGS += " -DRUBY_IS_19"
end

$LDFLAGS += " -module"
create_makefile("utilrb_ext")

