#include <ruby.h>
#include <set>

#ifndef RUBINIUS
#ifdef RUBY_IS_19
#include "ruby_internals-1.9.h"
#else
#include "ruby_internals-1.8.h"
#endif
#endif

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

#ifndef RUBY_IS_19

/* call-seq:
 *  proc.same_body?(other) => true or false
 *
 * Returns true if +self+ and +other+ have the same body
 */
static VALUE proc_same_body_p(VALUE self, VALUE other)
{
    if (self == other) return Qtrue;
    if (TYPE(other) != T_DATA) return Qfalse;
    if (RDATA(other)->dmark != RDATA(self)->dmark) return Qfalse;
    if (CLASS_OF(self) != CLASS_OF(other)) return Qfalse;

    struct BLOCK* data, *data2;
    Data_Get_Struct(self, struct BLOCK, data);
    Data_Get_Struct(other, struct BLOCK, data2);
    return (data->body == data2->body) ? Qtrue : Qfalse;
}

/* call-seq:
 *  proc.file
 *
 * Returns the file in which the proc body is defined, or nil
 */
static VALUE proc_file(VALUE self)
{ 
    struct BLOCK *data;
    NODE *node;

    Data_Get_Struct(self, struct BLOCK, data);
    if ((node = data->frame.node) || (node = data->body)) 
	return rb_str_new2(node->nd_file);
    else 
	return Qnil;
}

/* call-seq:
 *  proc.line
 *
 * Returns the line at which the proc body is defined, or nil
 */
static VALUE proc_line(VALUE self)
{
    struct BLOCK *data;
    NODE *node;

    Data_Get_Struct(self, struct BLOCK, data);
    if ((node = data->frame.node) || (node = data->body)) 
	return INT2FIX(nd_line(node));
    else
	return Qnil;
}

#endif

static VALUE kernel_is_immediate(VALUE klass, VALUE object)
{ return IMMEDIATE_P(object) ? Qtrue : Qfalse; }
#endif

static VALUE kernel_crash(VALUE klass)
{ *((int*)0) = 10; }

extern "C" void Init_value_set();
extern "C" void Init_swap();
extern "C" void Init_weakref(VALUE mUtilrb);
extern "C" void Init_proc();

extern "C" void Init_utilrb()
{
    mUtilrb = rb_define_module("Utilrb");

#ifndef RUBINIUS
    rb_define_method(rb_mEnumerable, "each_uniq", RUBY_METHOD_FUNC(enumerable_each_uniq), 0);
    rb_define_method(rb_mKernel, "is_singleton?", RUBY_METHOD_FUNC(kernel_is_singleton_p), 0);
#ifndef RUBY_IS_19
    rb_define_method(rb_cProc, "same_body?", RUBY_METHOD_FUNC(proc_same_body_p), 1);
    rb_define_method(rb_cProc, "file", RUBY_METHOD_FUNC(proc_file), 0);
    rb_define_method(rb_cProc, "line", RUBY_METHOD_FUNC(proc_line), 0);
#endif

    rb_define_singleton_method(rb_mKernel, "crash!", RUBY_METHOD_FUNC(kernel_crash), 0);
    rb_define_singleton_method(rb_mKernel, "immediate?", RUBY_METHOD_FUNC(kernel_is_immediate), 1);

    Init_swap();
    Init_weakref(mUtilrb);
#endif

    Init_proc();

    Init_value_set();
}

