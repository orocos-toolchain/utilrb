#include <readline/readline.h>
#include <ruby.h>

static VALUE readline_save_prompt(VALUE self)
{
    rl_save_prompt();
    return Qnil;
}

static VALUE readline_message(VALUE self, VALUE msg)
{
    rl_message("%s", StringValuePtr(msg));
    rl_redisplay();
    return Qnil;
}

static VALUE readline_print(VALUE self, VALUE msg)
{
    int need_hack = (rl_readline_state & RL_STATE_READCMD) > 0;
    char *saved_line;
    int saved_point;
    if (need_hack)
    {
        saved_point = rl_point;
        saved_line = rl_copy_text(0, rl_end);
        rl_save_prompt();
        rl_replace_line("", 0);
        rl_redisplay();
    }

    printf("%s", StringValuePtr(msg));

    if (need_hack)
    {
        rl_restore_prompt();
        rl_replace_line(saved_line, 0);
        rl_point = saved_point;
        rl_redisplay();
        free(saved_line);
    }
    return Qnil;
}

extern void Init_utilrb_readline()
{
    VALUE mReadline = rb_define_module("Readline");
    rb_define_singleton_method(mReadline, "save_prompt", readline_save_prompt, 0);
    rb_define_singleton_method(mReadline, "message", readline_message, 1);
    rb_define_singleton_method(mReadline, "print", readline_print, 1);
}

