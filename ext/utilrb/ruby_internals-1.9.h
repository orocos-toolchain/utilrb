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
#include <ruby/re.h>

typedef struct RNode {
    unsigned long flags;
    char *nd_file;
    union {
	struct RNode *node;
	ID id;
	VALUE value;
	VALUE (*cfunc)(ANYARGS);
	ID *tbl;
    } u1;
    union {
	struct RNode *node;
	ID id;
	long argc;
	VALUE value;
    } u2;
    union {
	struct RNode *node;
	ID id;
	long state;
	struct global_entry *entry;
	long cnt;
	VALUE value;
    } u3;
} NODE;

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
	struct RRational rational;
	struct RComplex complex;
    } as;
} RVALUE;

static const size_t SLOT_SIZE = sizeof(RVALUE);

#endif

