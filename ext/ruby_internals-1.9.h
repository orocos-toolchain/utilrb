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
#include <ruby/intern.h>
#include <ruby/node.h>
#include <ruby/re.h>

typedef struct RVALUE {
    union {
	struct {
	    VALUE flags;		/* always 0 for freed obj */
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
    } as;
#ifdef GC_DEBUG
    char *file;
    int   line;
#endif
} RVALUE;

static const size_t SLOT_SIZE = sizeof(RVALUE);

#endif

