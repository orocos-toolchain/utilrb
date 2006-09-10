#include <ruby.h>
#include <set>
#include <algorithm>

using namespace std;
// static VALUE cFasterSet;
// static ID id_new;
 static ID id_enum_args;
// 
// typedef std::set<VALUE> ValueSet;
// static ValueSet& get_wrapped_set(VALUE self)
// {
//     void* object = 0;
//     Data_Get_Struct(self, void, object);
//     return *reinterpret_cast<ValueSet*>(object);
// }
// static void faster_set_mark(ValueSet const* set)
// { std::for_each(set->begin(), set->end(), rb_gc_mark); }
// static void faster_set_free(ValueSet const* set)
// { delete set; }
// static VALUE faster_set_alloc(VALUE klass)
// {
//     ValueSet* cxx_set = new ValueSet;
//     return Data_Wrap_Struct(klass, faster_set_mark, faster_set_free, cxx_set);
// }
// static VALUE faster_set_each(VALUE self)
// {
//     ValueSet& set = get_wrapped_set(self);
//     for (ValueSet::const_iterator it = set.begin(); it != set.end(); ++it)
// 	rb_yield_values(1, *it);
//     return self;
// }
// static VALUE faster_set_include_p(VALUE vself, VALUE vother)
// {
//     ValueSet const& self  = get_wrapped_set(vself);
//     ValueSet const& other = get_wrapped_set(vother);
//     return std::includes(self.begin(), self.end(), other.begin(), other.end()) ? Qtrue : Qfalse;
// }
// static VALUE faster_set_union(VALUE vself, VALUE vother)
// {
//     ValueSet const& self  = get_wrapped_set(vself);
//     ValueSet const& other = get_wrapped_set(vother);
//     
//     VALUE vresult = rb_funcall(cFasterSet, id_new, 0);
//     ValueSet& result = get_wrapped_set(vresult);
//     std::set_union(self.begin(), self.end(), other.begin(), other.end(), 
// 	    std::inserter(result, result.end()));
//     return vresult;
// }
// static VALUE faster_set_intersection(VALUE vself, VALUE vother)
// {
//     ValueSet const& self  = get_wrapped_set(vself);
//     ValueSet const& other = get_wrapped_set(vother);
//     
//     VALUE vresult = rb_funcall(cFasterSet, id_new, 0);
//     ValueSet& result = get_wrapped_set(vresult);
//     std::set_intersection(self.begin(), self.end(), other.begin(), other.end(), 
// 	    std::inserter(result, result.end()));
//     return vresult;
// }
// static VALUE faster_set_difference(VALUE vself, VALUE vother)
// {
//     ValueSet const& self  = get_wrapped_set(vself);
//     ValueSet const& other = get_wrapped_set(vother);
//     
//     VALUE vresult = rb_funcall(cFasterSet, id_new, 0);
//     ValueSet& result = get_wrapped_set(vresult);
//     std::set_difference(self.begin(), self.end(), other.begin(), other.end(), 
// 	    std::inserter(result, result.end()));
//     return vresult;
// }








// static VALUE enumerable_to_faster_set_i(VALUE i, VALUE* memo)
// {
//     ValueSet& result = *reinterpret_cast<ValueSet*>(memo);
//     result.insert(i);
//     return Qnil;
// }
// static VALUE enumerable_to_faster_set(VALUE self)
// {
//     VALUE vresult = rb_funcall(cFasterSet, id_new, 0);
//     ValueSet& result = get_wrapped_set(vresult);
//     rb_iterate(rb_each, self, 
// 	    RUBY_METHOD_FUNC(enumerable_to_faster_set_i), (VALUE)&result);
//     return vresult;
// }

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
    VALUE rb_cEnumerator = rb_define_class_under(rb_mEnumerable, "Enumerator", rb_cObject);
    rb_define_method(rb_mEnumerable, "each_uniq", RUBY_METHOD_FUNC(enumerable_each_uniq), 0);
    // rb_define_method(rb_mEnumerable, "to_faster_set", RUBY_METHOD_FUNC(enumerable_to_faster_set), 0);

    //cFasterSet = rb_define_class("FasterSet", rb_cObject);
    //rb_define_alloc_func(cFasterSet, faster_set_alloc);
    //rb_define_method(cFasterSet, "each", RUBY_METHOD_FUNC(faster_set_each), 0);
    //rb_define_method(cFasterSet, "include?", RUBY_METHOD_FUNC(faster_set_include_p), 1);
    //rb_define_method(cFasterSet, "union", RUBY_METHOD_FUNC(faster_set_union), 1);
    //rb_define_method(cFasterSet, "intersection", RUBY_METHOD_FUNC(faster_set_intersection), 1);

    id_enum_args	= rb_intern("enum_args");
    rb_define_method(rb_cEnumerator, "args", RUBY_METHOD_FUNC(enumerator_args_get), 0);
    rb_define_method(rb_cEnumerator, "args=", RUBY_METHOD_FUNC(enumerator_args_set), 1);
}

