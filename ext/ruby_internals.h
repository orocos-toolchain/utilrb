#ifndef __RUBY_INTERNALS_HH__
#define __RUBY_INTERNALS_HH__

/* WARNING: this file contains copies of internal Ruby structures. They are not supposed to be copied (I think ;-)), but I had to nonetheless.
 * The following methods depend on these:
 *
 *   Kernel.swap!
 *   Proc#same_body?
 *   Proc#file
 *   Proc#line
 */

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

/* This is a copy of Ruby 1.8.5 BLOCK structure. It sucks to copy it here,
 * but it is not public in Ruby and it is needed to define same_body? */
struct BLOCK {
    NODE *var;
    NODE *body;
    VALUE self;
    struct FRAME frame;
    struct SCOPE *scope;
    VALUE klass;
    NODE *cref;
    int iter;
    int vmode;
    int flags;
    int uniq;
    struct RVarmap *dyna_vars;
    VALUE orig_thread;
    VALUE wrapper;
    VALUE block_obj;
    struct BLOCK *outer;
    struct BLOCK *prev;
};

#endif

