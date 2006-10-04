#include <ruby.h>
#include <intern.h>
#include <node.h>
#include <re.h>
#include <env.h>

typedef struct RVALUE {
    union {
        struct {
            unsigned long flags;        /* always 0 for freed obj */
            struct RVALUE *next;
        } free;
        struct RBasic  basic;
        struct RObject object;
        struct RClass  klass;
        struct RFloat  flonum;
        struct RString string;
        struct RArray  array;
        struct RRegexp regexp;
        struct RHash   hash;
        struct RData   data;
        struct RStruct rstruct;
        struct RBignum bignum;
        struct RFile   file;
        struct RNode   node;
        struct RMatch  match;
        struct RVarmap varmap;
        struct SCOPE   scope;
    } as;
#ifdef GC_DEBUG
    char *file;
    int   line;
#endif
} RVALUE;
static const size_t SLOT_SIZE = sizeof(RVALUE);

/*
 * Kernel.replace!(object, klass, *args)
 *
 * Replaces +object+ by a new object of class +klass+. klass::new is called
 * with the provided arguments
 *
 * WARNING: I don't know if this can be called in a method of +object+
 */
static VALUE kernel_replace_bang(int argc, VALUE* argv, VALUE self)
{
    VALUE obj;
    VALUE klass;
    rb_scan_args(argc, argv, "2*", &obj, &klass);

    // Create the new object
    VALUE newobj = rb_funcall2(klass, rb_intern("new"), argc - 2, argv + 2);
    // Save the definition of the old object
    RVALUE old_obj;
    memcpy(&old_obj, reinterpret_cast<void*>(newobj), SLOT_SIZE);
    // Place the definition of the new object in the slot of the old one
    memcpy(reinterpret_cast<void*>(obj), reinterpret_cast<void*>(newobj), SLOT_SIZE);
    // Place the definition of the old object in the slot of the new one
    memcpy(reinterpret_cast<void*>(newobj), &old_obj, SLOT_SIZE);

    return obj;
}

extern "C" void Init_replace()
{
    rb_define_singleton_method(rb_mKernel, "replace!", RUBY_METHOD_FUNC(kernel_replace_bang), -1);
}

