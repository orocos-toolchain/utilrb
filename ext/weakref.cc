#include <set>
#include <map>
#include <ruby.h>
#include <intern.h>

using std::set;
using std::map;

static VALUE cWeakRef;
static VALUE cRefError;

/* Weakref internal structure. +obj+ is Qnil before initialization and Qundef
 * after finalization */
struct WeakRef {
    VALUE obj;
};

// Map from real objects to the set of associated WeakRef objects
typedef set<VALUE> ObjSet;
typedef map< VALUE, ObjSet > RefFromObjID;
typedef map< VALUE, VALUE > ObjFromRefID;
RefFromObjID from_obj_id;
ObjFromRefID from_ref_id;

static void weakref_free(WeakRef const* set) { delete set; }
static VALUE weakref_alloc(VALUE klass)
{
    WeakRef* ref = new WeakRef;
    ref->obj = Qnil;
    return Data_Wrap_Struct(klass, NULL, weakref_free, ref);
}

static WeakRef& get_weakref(VALUE self)
{
    WeakRef* object = 0;
    Data_Get_Struct(self, WeakRef, object);
    return *object;
}

static VALUE do_object_finalize(VALUE mod, VALUE obj_id)
{
    RefFromObjID::iterator ref_set = from_obj_id.find(obj_id);
    if (ref_set != from_obj_id.end())
    {
        ObjSet::iterator it = ref_set->second.begin();
        ObjSet::iterator const end = ref_set->second.end();
        for (; it != end; ++it)
        {
            /* During GC, objects are garbage collected and *then* the finalizers are called. It means that, even though *it is referenced in from_obj_id, it may be invalid.
             *
             * When an object is marked for deferred finalization, its flags
             * are reset to a special value (flags = FL_MARK). FL_FINALIZE
             * should therefore not be set on it anymore.
             */
            if (FL_TEST(*it, FL_FINALIZE))
            {
                WeakRef& ref = get_weakref(*it);
                ref.obj = Qundef;
            }
            from_ref_id.erase(rb_obj_id(*it));
        }

        from_obj_id.erase(obj_id);
    }
    return Qnil;
}

static VALUE do_weakref_finalize(VALUE mod, VALUE ref_id)
{
    ObjFromRefID::iterator obj_it = from_ref_id.find(ref_id);
    if (obj_it != from_ref_id.end())
    {
        VALUE obj_id = rb_obj_id(obj_it->second);
        RefFromObjID::iterator ref_set = from_obj_id.find(obj_id);
        ref_set->second.erase(ref_id & ~FIXNUM_FLAG);
        from_ref_id.erase(obj_it);
    }
    return Qnil;
}

// Note: the Ruby code has already registered +do_object_finalize+ as the
// finalizer for +obj+, and +do_weakref_finalize+ for +self+.
//
// It is forbidden to make a weakref-of-weakref or a weakref of an immediate
// object
static VALUE weakref_do_initialize(VALUE self, VALUE obj)
{
    if (!FL_ABLE(obj))
    {
        VALUE str = rb_any_to_s(obj);
        rb_raise(rb_eArgError, "%s cannot be finalized", StringValuePtr(str));
    }

    WeakRef& ref = get_weakref(self);
    ref.obj = obj;

    RefFromObjID::iterator it = from_obj_id.find(rb_obj_id(obj));
    if (it == from_obj_id.end())
        it = from_obj_id.insert( make_pair(rb_obj_id(obj), ObjSet()) ).first;

    it->second.insert(self);
    from_ref_id.insert( std::make_pair(rb_obj_id(self), obj) );

    return Qnil;
}

static VALUE weakref_get(VALUE self)
{
    WeakRef const& ref = get_weakref(self);

    if (ref.obj == Qnil)
        rb_raise(cRefError, "initialized weakref");
    if (ref.obj == Qundef)
        rb_raise(cRefError, "finalized object");
    return ref.obj;
}

static VALUE refcount(VALUE mod, VALUE obj)
{
    if (0 == obj & FIXNUM_FLAG)
        obj = rb_obj_id(obj);

    RefFromObjID::const_iterator it = from_obj_id.find(obj);
    if (it == from_obj_id.end())
        return Qnil;
    else
        return INT2FIX(it->second.size());
}

extern "C" void Init_weakref(VALUE mUtilrb)
{
    cWeakRef = rb_define_class_under(mUtilrb, "WeakRef", rb_cObject);
    cRefError = rb_define_class_under(cWeakRef, "RefError", rb_eStandardError);
    rb_define_alloc_func(cWeakRef, weakref_alloc);

    rb_define_singleton_method(cWeakRef, "do_object_finalize", RUBY_METHOD_FUNC(do_object_finalize), 1);
    rb_define_singleton_method(cWeakRef, "do_weakref_finalize", RUBY_METHOD_FUNC(do_weakref_finalize), 1);
    rb_define_singleton_method(cWeakRef, "refcount", RUBY_METHOD_FUNC(refcount), 1);
    rb_define_method(cWeakRef, "do_initialize", RUBY_METHOD_FUNC(weakref_do_initialize), 1);
    rb_define_method(cWeakRef, "get", RUBY_METHOD_FUNC(weakref_get), 0);
}

