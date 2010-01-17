/* -*- Mode: C -*- */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

static char *
make_dest(SV *t, STRLEN len) {
    char *tp = SvGROW(t, len + 1);
    SvPOK_on(t);
    SvCUR_set(t, len);
    tp[len] = '\0';
    return tp;
}

#define BITOP_AND   1
#define BITOP_OR    2
#define BITOP_XOR   3
#define BITOP_IMP   4
#define BITOP_PMI   5

#define BITOP_NAND  6
#define BITOP_NOR   7
#define BITOP_NXOR  8
#define BITOP_NIMP  9
#define BITOP_NPMI 10

static void
iv_and(IV *a, IV *b, IV* t, IV *btop) {
    while (b < btop) *t++ = *a++ & *b++;
}

static void
char_and(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = *a++ & *b++;
}

static void
iv_or(IV *a, IV *b, IV* t, IV *btop) {
    while (b < btop) *t++ = *a++ | *b++;
}

static void
char_or(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = *a++ | *b++;
}

static void
iv_xor(IV *a, IV *b, IV* t, IV *btop) {
    while (b < btop) *t++ = *a++ ^ *b++;
}

static void
char_xor(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = *a++ ^ *b++;
}

static void
iv_imp(IV *a, IV *b, IV* t, IV *btop) {
    while (b < btop) *t++ = ~*a++ | *b++;
}

static void
char_imp(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = ~*a++ | *b++;
}

static void
iv_pmi(IV *a, IV *b, IV* t, IV *btop) {
    while (b < btop) *t++ = *a++ | ~*b++;
}

static void
char_pmi(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = *a++ | ~*b++;
}

static void
iv_nand(IV *a, IV *b, IV* t, IV *btop) {
    while (b < btop) *t++ = ~(*a++ & *b++);
}

static void
char_nand(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = ~(*a++ & *b++);
}

static void
iv_nor(IV *a, IV *b, IV* t, IV *btop) {
    while (b < btop) *t++ = ~(*a++ | *b++);
}

static void
char_nor(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = ~(*a++ | *b++);
}

static void
iv_nxor(IV *a, IV *b, IV* t, IV *btop) {
    while (b < btop) *t++ = ~(*a++ ^ *b++);
}

static void
char_nxor(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = ~(*a++ ^ *b++);
}

static void
iv_nimp(IV *a, IV *b, IV* t, IV *btop) {
    while (b < btop) *t++ = *a++ & ~*b++;
}

static void
char_nimp(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = *a++ & ~*b++;
}

static void
iv_npmi(IV *a, IV *b, IV* t, IV *btop) {
    while (b < btop) *t++ = ~*a++ & *b++;
}

static void
char_npmi(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = ~*a++ & *b++;
}


MODULE = Math::Packed		PACKAGE = Math::Packed		

void
_mp_bitop(packer, a, b, t = NULL)
    SV *packer
    SV *a
    SV *b
    SV *t
ALIAS:
    mp_and = BITOP_AND
    mp_or = BITOP_OR
    mp_xor = BITOP_XOR
    mp_neqv = BITOP_XOR
    mp_nand = BITOP_NAND
    mp_nor = BITOP_NOR
    mp_eqv = BITOP_NXOR
    mp_nxor = BITOP_NXOR
CODE:
{
    void (*iv_bitop)(IV *, IV *, IV *, IV *);
    void (*char_bitop)(char *, char *, char *, char *);
    STRLEN al, bl, bli;
    char *ap, *bp, *tp, *btop, *btopi;

    switch (ix) {
    case BITOP_AND:
        iv_bitop = &iv_and;
        char_bitop = &char_and;
        break;
    case BITOP_OR:
        iv_bitop = &iv_or;
        char_bitop = &char_or;
        break;
    case BITOP_XOR:
        iv_bitop = &iv_xor;
        char_bitop = &char_xor;
        break;
    case BITOP_IMP:
        iv_bitop = &iv_imp;
        char_bitop = &char_imp;
        break;
    case BITOP_PMI:
        iv_bitop = &iv_pmi;
        char_bitop = &char_pmi;
        break;

    case BITOP_NAND:
        iv_bitop = &iv_and;
        char_bitop = &char_and;
        break;
    case BITOP_NOR:
        iv_bitop = &iv_or;
        char_bitop = &char_or;
        break;
    case BITOP_NXOR:
        iv_bitop = &iv_xor;
        char_bitop = &char_xor;
        break;
    case BITOP_NIMP:
        iv_bitop = &iv_nimp;
        char_bitop = &char_nimp;
        break;
    case BITOP_NPMI:
        iv_bitop = &iv_npmi;
        char_bitop = &char_npmi;
        break;

    default:
        croak("bitop %d not implemented yet!", ix);
    }

    al = SvCUR(a);
    if (!al) return;
    bl = SvCUR(b);
    if (!bl) croak("length of secondary argument is zero");
    if (!t) t = a;
    if (t == b && bl < al) b = sv_2mortal(newSVsv(b));
    tp = make_dest(t, al);
    ap = SvPV_nolen(a);
    bp = SvPV_nolen(b);

    if (bl <= al) goto set_top;

    while (1) {
        /* fprintf(stderr, "bl: %ld, al: %ld, bli: %ld, ap: %p, bp: %p, tp: %p, btop: %p, btopi: %p\n",
           bl, al, bli, ap, bp, tp, btop, btopi); */
        if (bl > al) {
            bl = al;
          set_top:
            btop = bp + bl;
            bli = bl & ~(sizeof(IV) - 1);
            btopi = bp + bli;
        }
        if (((IV)ap | (IV)bp | (IV)tp) & (sizeof(IV) - 1))
            (*char_bitop)(ap, bp, tp, btop);
        else {
            (*iv_bitop)((IV*)ap, (IV*)bp, (IV*)tp, (IV*)btopi);
            if (bli < bl)
                (*char_bitop)(ap + bli, bp + bli, tp + bli, btop);
        }
        al -= bl;
        if (!al) return;
        ap += bl;
        tp += bl;
    }
 }

