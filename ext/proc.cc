#ifdef HAS_RUBY_SOURCE
extern "C" {
#include "/usr/include/ruby-1.9.1/ruby-1.9.3-p0/vm_core.h"
}

static VALUE env_references(VALUE rbenv)
{
    rb_env_t* env;

    VALUE result = rb_ary_new();
    GetEnvPtr(rbenv, env);
    if (env->env)
    {
        for (int i = 0; i < env->env_size; ++i)
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
#else
#warning "RUBY_SOURCE_DIR is not set, Proc#references will not be available"
#endif

extern "C" void Init_proc()
{
#ifdef HAS_RUBY_SOURCE
    rb_define_method(rb_cProc, "references", RUBY_METHOD_FUNC(proc_references), 0);
#endif
}
