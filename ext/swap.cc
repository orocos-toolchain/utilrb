#ifdef RUBY_IS_19
#include "ruby_internals-1.9.h"
#else
#include "ruby_internals-1.8.h"
#endif

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

