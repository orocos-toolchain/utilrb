#include <ruby.h>
#include <set>

using namespace std;
static ID id_enum_args;

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

static VALUE enumerable_each_uniq(VALUE self)
{
    set<VALUE> seen;
    rb_iterate(rb_each, self, 
	    RUBY_METHOD_FUNC(enumerable_each_uniq_i), (VALUE)&seen);
    return self;
}

static VALUE enumerator_args_get(VALUE self)
{ return rb_ivar_get(self, id_enum_args); }
static VALUE enumerator_args_set(VALUE self, VALUE args)
{
    rb_ivar_set(self, id_enum_args, args);
    return args;
}


extern "C" void Init_faster()
{
    rb_define_method(rb_mEnumerable, "each_uniq", RUBY_METHOD_FUNC(enumerable_each_uniq), 0);

    id_enum_args	= rb_intern("enum_args");
    VALUE rb_cEnumerator = rb_define_class_under(rb_mEnumerable, "Enumerator", rb_cObject);
    rb_define_method(rb_cEnumerator, "args", RUBY_METHOD_FUNC(enumerator_args_get), 0);
    rb_define_method(rb_cEnumerator, "args=", RUBY_METHOD_FUNC(enumerator_args_set), 1);
}

