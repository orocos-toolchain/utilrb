#include <ruby.h>
#include <set>

#ifdef RUBY_IS_19
#include "ruby_internals-1.9.h"
#else
#include "ruby_internals-1.8.h"
#endif

using namespace std;

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

extern "C" void Init_value_set();
extern "C" void Init_swap();

extern "C" void Init_faster()
{
    rb_define_method(rb_mEnumerable, "each_uniq", RUBY_METHOD_FUNC(enumerable_each_uniq), 0);
    rb_define_method(rb_mKernel, "is_singleton?", RUBY_METHOD_FUNC(kernel_is_singleton_p), 0);

    Init_value_set();
    Init_swap();
}

