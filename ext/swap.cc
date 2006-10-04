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
 * Kernel.swap!(obj1, obj2, *args)
 *
 * Swaps the object which are being hold by obj1 and obj2.
 *
 * WARNING: I don't know if this can be called in a method of +obj1+ or +obj2+
 */
static VALUE kernel_swap_bang(VALUE self, VALUE obj1, VALUE obj2)
{
    // Save the definition of the old object
    RVALUE old_obj;
    memcpy(&old_obj, reinterpret_cast<void*>(obj1), SLOT_SIZE);
    // Place the definition of the new object in the slot of the old one
    memcpy(reinterpret_cast<void*>(obj1), reinterpret_cast<void*>(obj2), SLOT_SIZE);
    // Place the definition of the old object in the slot of the new one
    memcpy(reinterpret_cast<void*>(obj2), &old_obj, SLOT_SIZE);

    return Qnil;
}

extern "C" void Init_swap()
{
    rb_define_singleton_method(rb_mKernel, "swap!", RUBY_METHOD_FUNC(kernel_swap_bang), 2);
}

