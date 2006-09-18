#include <ruby.h>
#include <set>
#include <algorithm>

#include <boost/tuple/tuple.hpp>

using namespace boost;
using namespace std;

static VALUE cValueSet;
static ID id_new;
static ID id_to_value_set;

typedef std::set<VALUE> ValueSet;
static ValueSet& get_wrapped_set(VALUE self)
{
    void* object = 0;
    Data_Get_Struct(self, void, object);
    return *reinterpret_cast<ValueSet*>(object);
}
static void value_set_mark(ValueSet const* set)
{ std::for_each(set->begin(), set->end(), rb_gc_mark); }
static void value_set_free(ValueSet const* set)
{ delete set; }
static VALUE value_set_alloc(VALUE klass)
{
    ValueSet* cxx_set = new ValueSet;
    return Data_Wrap_Struct(klass, value_set_mark, value_set_free, cxx_set);
}
static VALUE value_set_each(VALUE self)
{
    ValueSet& set = get_wrapped_set(self);
    for_each(set.begin(), set.end(), rb_yield);
    return self;
}
static VALUE value_set_include_p(VALUE vself, VALUE vother)
{
    ValueSet const& self  = get_wrapped_set(vself);
    return self.find(vother) == self.end() ? Qfalse : Qtrue;
}
static VALUE value_set_to_value_set(VALUE self) { return self; }
static VALUE value_set_include_all_p(VALUE vself, VALUE vother)
{
    ValueSet const& self  = get_wrapped_set(vself);
    ValueSet const& other = get_wrapped_set(rb_funcall(vother, id_to_value_set, 0));
    return std::includes(self.begin(), self.end(), other.begin(), other.end()) ? Qtrue : Qfalse;
}

static VALUE value_set_union(VALUE vself, VALUE vother)
{
    ValueSet const& self  = get_wrapped_set(vself);
    ValueSet const& other = get_wrapped_set(vother);
    
    VALUE vresult = rb_funcall(cValueSet, id_new, 0);
    ValueSet& result = get_wrapped_set(vresult);
    std::set_union(self.begin(), self.end(), other.begin(), other.end(), 
	    std::inserter(result, result.end()));
    return vresult;
}

/* call-seq:
 *  set.merge(other)		=> set
 *
 * Merges the elements of +other+ into +self+. If +other+ is a ValueSet, the operation is O(N + M)
 */
static VALUE value_set_merge(VALUE vself, VALUE vother)
{
    ValueSet& self  = get_wrapped_set(vself);
    ValueSet const& other = get_wrapped_set(rb_funcall(vother, id_to_value_set, 0));
    
    self.insert(other.begin(), other.end());
    return vself;
}

/* call-seq:
 *   set.intersection(other)	=> intersection_set
 *   set & other		=> intersection_set
 *
 * Computes the intersection of +set+ and +other+
 */
static VALUE value_set_intersection(VALUE vself, VALUE vother)
{
    ValueSet const& self  = get_wrapped_set(vself);
    ValueSet const& other = get_wrapped_set(rb_funcall(vother, id_to_value_set, 0));
    
    VALUE vresult = rb_funcall(cValueSet, id_new, 0);
    ValueSet& result = get_wrapped_set(vresult);
    std::set_intersection(self.begin(), self.end(), other.begin(), other.end(), 
	    std::inserter(result, result.end()));
    return vresult;
}
static VALUE value_set_difference(VALUE vself, VALUE vother)
{
    ValueSet const& self  = get_wrapped_set(vself);
    ValueSet const& other = get_wrapped_set(rb_funcall(vother, id_to_value_set, 0));
    
    VALUE vresult = rb_funcall(cValueSet, id_new, 0);
    ValueSet& result = get_wrapped_set(vresult);
    std::set_difference(self.begin(), self.end(), other.begin(), other.end(), 
	    std::inserter(result, result.end()));
    return vresult;
}

static VALUE value_set_insert(VALUE vself, VALUE v)
{
    ValueSet& self  = get_wrapped_set(vself);
    bool exists;
    tie(tuples::ignore, exists) = self.insert(v);
    return exists ? Qtrue : Qfalse;
}
static VALUE value_set_delete(VALUE vself, VALUE v)
{
    ValueSet& self  = get_wrapped_set(vself);
    size_t count = self.erase(v);
    return count > 0 ? Qtrue : Qfalse;
}

/* call-seq:
 *  set == other		=> true or false
 *
 * Equality
 */
static VALUE value_set_equal(VALUE vself, VALUE vother)
{
    ValueSet const& self  = get_wrapped_set(vself);
    ValueSet const& other = get_wrapped_set(rb_funcall(vother, id_to_value_set, 0));
    return (self == other) ? Qtrue : Qfalse;
}








static VALUE enumerable_to_value_set_i(VALUE i, VALUE* memo)
{
    ValueSet& result = *reinterpret_cast<ValueSet*>(memo);
    result.insert(i);
    return Qnil;
}
static VALUE enumerable_to_value_set(VALUE self)
{
    VALUE vresult = rb_funcall(cValueSet, id_new, 0);
    ValueSet& result = get_wrapped_set(vresult);

    rb_iterate(rb_each, self, RUBY_METHOD_FUNC(enumerable_to_value_set_i), reinterpret_cast<VALUE>(&result));
    return vresult;
}

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


extern "C" void Init_faster()
{
    rb_define_method(rb_mEnumerable, "each_uniq", RUBY_METHOD_FUNC(enumerable_each_uniq), 0);
    rb_define_method(rb_mEnumerable, "to_value_set", RUBY_METHOD_FUNC(enumerable_to_value_set), 0);

    cValueSet = rb_define_class("ValueSet", rb_cObject);
    id_new = rb_intern("new");
    id_to_value_set = rb_intern("to_value_set");
    rb_define_alloc_func(cValueSet, value_set_alloc);
    rb_define_method(cValueSet, "each", RUBY_METHOD_FUNC(value_set_each), 0);
    rb_define_method(cValueSet, "include?", RUBY_METHOD_FUNC(value_set_include_p), 1);
    rb_define_method(cValueSet, "include_all?", RUBY_METHOD_FUNC(value_set_include_all_p), 1);
    rb_define_method(cValueSet, "union", RUBY_METHOD_FUNC(value_set_union), 1);
    rb_define_method(cValueSet, "intersection", RUBY_METHOD_FUNC(value_set_intersection), 1);
    rb_define_method(cValueSet, "difference", RUBY_METHOD_FUNC(value_set_difference), 1);
    rb_define_method(cValueSet, "insert", RUBY_METHOD_FUNC(value_set_insert), 1);
    rb_define_method(cValueSet, "merge", RUBY_METHOD_FUNC(value_set_merge), 1);
    rb_define_method(cValueSet, "delete", RUBY_METHOD_FUNC(value_set_delete), 1);
    rb_define_method(cValueSet, "==", RUBY_METHOD_FUNC(value_set_equal), 1);
    rb_define_method(cValueSet, "to_value_set", RUBY_METHOD_FUNC(value_set_to_value_set), 0);
}

