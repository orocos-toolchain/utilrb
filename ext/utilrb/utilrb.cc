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

extern "C" void Init_utilrb()
{
    mUtilrb = rb_define_module("Utilrb");

#ifndef RUBINIUS
    rb_define_method(rb_mEnumerable, "each_uniq", RUBY_METHOD_FUNC(enumerable_each_uniq), 0);
    rb_define_singleton_method(rb_mKernel, "crash!", RUBY_METHOD_FUNC(kernel_crash), 0);
    rb_define_singleton_method(rb_mKernel, "immediate?", RUBY_METHOD_FUNC(kernel_is_immediate), 1);
#endif

    Init_value_set();
}

