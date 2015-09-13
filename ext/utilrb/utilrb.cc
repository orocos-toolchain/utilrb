#include <ruby.h>
#include <set>

static VALUE mUtilrb;

using namespace std;

#ifndef RUBINIUS
static VALUE enumerable_each_uniq_i(VALUE i, VALUE* memo)
{ 
    set<VALUE>& seen = *reinterpret_cast< set<VALUE>* >(memo); 
    if (seen.find(i) == seen.end())
    {
	seen.insert(i);
	return rb_yield(i);
    }
    else
	return Qnil;

}

/* :nodoc: */
static VALUE enumerable_each_uniq(VALUE self)
{
    set<VALUE> seen;
    rb_iterate(rb_each, self, 
	    RUBY_METHOD_FUNC(enumerable_each_uniq_i), (VALUE)&seen);
    return self;
}

/* call-seq:
 *  Kernel.is_singleton?(object)
 *
 * Returns true if +self+ is a singleton class 
 */
static VALUE kernel_is_singleton_p(VALUE self)
{
    if (BUILTIN_TYPE(self) == T_CLASS && FL_TEST(self, FL_SINGLETON))
	return Qtrue;
    else
	return Qfalse;
}

static VALUE kernel_is_immediate(VALUE klass, VALUE object)
{ return IMMEDIATE_P(object) ? Qtrue : Qfalse; }
#endif

static VALUE kernel_crash(VALUE klass)
{
    *((int*)0) = 10;
    // Return something to shut gcc up
    return Qfalse;
}

extern "C" void Init_value_set();
extern "C" void Init_weakref(VALUE mUtilrb);

extern "C" void Init_utilrb()
{
    mUtilrb = rb_define_module("Utilrb");

#ifndef RUBINIUS
    rb_define_method(rb_mEnumerable, "each_uniq", RUBY_METHOD_FUNC(enumerable_each_uniq), 0);
    if (!rb_respond_to(rb_mEnumerable, rb_intern("singleton_class?")))
        rb_define_method(rb_cModule, "singleton_class?", RUBY_METHOD_FUNC(kernel_is_singleton_p), 0);

    rb_define_singleton_method(rb_mKernel, "crash!", RUBY_METHOD_FUNC(kernel_crash), 0);
    rb_define_singleton_method(rb_mKernel, "immediate?", RUBY_METHOD_FUNC(kernel_is_immediate), 1);

    Init_weakref(mUtilrb);
#endif

    Init_value_set();
}

