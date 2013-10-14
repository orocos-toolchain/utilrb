#ifdef HAS_RUBY_SOURCE
#include <vm_core.h>

static VALUE env_references(VALUE rbenv)
{
    rb_env_t* env;

    VALUE result = rb_ary_new();
    GetEnvPtr(rbenv, env);
    if (env->env)
    {
        int i;
        for (i = 0; i < env->env_size; ++i)
            rb_ary_push(result, rb_obj_id(env->env[i]));
    }
    return result;
}

static VALUE proc_references(VALUE rbproc)
{
    rb_proc_t* proc;
    GetProcPtr(rbproc, proc);

    if (!NIL_P(proc->envval))
        return env_references(proc->envval);
    return rb_ary_new();
}
#elif RUBY_IS_18
#warning "compiling on Ruby 1.8, Proc#references will not be available"
#else
#warning "Ruby core sources cannot be found, Proc#references will not be available. Install the debugger-ruby_core_source gem to enable"
#endif

void Init_proc()
{
#ifdef HAS_RUBY_SOURCE
    rb_define_method(rb_cProc, "references", RUBY_METHOD_FUNC(proc_references), 0);
#endif
}
