/* -*- Mode: C -*- */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

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

typedef struct vtable_ {
    char packer;
    STRLEN size;
    void (*bvgrep)(char **ap, char *bvp, char **tp,
		   STRLEN al, STRLEN bvl, STRLEN tl);
} vtable;

static void
bvgrep_uv(char *ap, char *bvp, char *tp,
	  STRLEN *al, STRLEN bvl, STRLEN *tl) {
    UV *api = (UV*)*ap;
    UV *tpi = (UV*)*tp;
    for (; api < atopi; api++) {
	UV uv = *api;
	int bit = uv & 7;
	STRLEN byte = uv >> 3;
	if (byte < bvl && ((bvp[byte] >> bit) & 1)) {
	    if (tpi < ttopi)
		*tpi++ = uv;
	    else break;
	}
    }
    *ap = (char*)api;
    *tp = (char*)tpi;
}

static vtable vtable_J = { 'J',
			   sizeof(UV),
			   &bvgrep_uv, };

static vtable *
find_vtable(char packer) {
    switch (packer) {
    case 'J':
	return &vtable_J;
    default:
	croak("unsupported packed '%c'", packer);
    }
}

static void
uv_and(UV *a, UV *b, UV* t, UV *btop) {
    while (b < btop) *t++ = *a++ & *b++;
}

static void
char_and(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = *a++ & *b++;
}

static void
uv_or(UV *a, UV *b, UV* t, UV *btop) {
    while (b < btop) *t++ = *a++ | *b++;
}

static void
char_or(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = *a++ | *b++;
}

static void
uv_xor(UV *a, UV *b, UV* t, UV *btop) {
    while (b < btop) *t++ = *a++ ^ *b++;
}

static void
char_xor(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = *a++ ^ *b++;
}

static void
uv_imp(UV *a, UV *b, UV* t, UV *btop) {
    while (b < btop) *t++ = ~*a++ | *b++;
}

static void
char_imp(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = ~*a++ | *b++;
}

static void
uv_pmi(UV *a, UV *b, UV* t, UV *btop) {
    while (b < btop) *t++ = *a++ | ~*b++;
}

static void
char_pmi(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = *a++ | ~*b++;
}

static void
uv_nand(UV *a, UV *b, UV* t, UV *btop) {
    while (b < btop) *t++ = ~(*a++ & *b++);
}

static void
char_nand(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = ~(*a++ & *b++);
}

static void
uv_nor(UV *a, UV *b, UV* t, UV *btop) {
    while (b < btop) *t++ = ~(*a++ | *b++);
}

static void
char_nor(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = ~(*a++ | *b++);
}

static void
uv_nxor(UV *a, UV *b, UV* t, UV *btop) {
    while (b < btop) *t++ = ~(*a++ ^ *b++);
}

static void
char_nxor(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = ~(*a++ ^ *b++);
}

static void
uv_nimp(UV *a, UV *b, UV* t, UV *btop) {
    while (b < btop) *t++ = *a++ & ~*b++;
}

static void
char_nimp(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = *a++ & ~*b++;
}

static void
uv_npmi(UV *a, UV *b, UV* t, UV *btop) {
    while (b < btop) *t++ = ~*a++ & *b++;
}

static void
char_npmi(char *a, char *b, char *t, char *btop) {
    while (b < btop) *t++ = ~*a++ & *b++;
}

static char *
make_dest(SV *t, STRLEN len, int discard_old) {
    char *tp;
    SvUPGRADE(t, SVt_PV);
    if (discard_old || !SvPOK(t)) {
	SvPOK_on(t);
	SvCUR_set(t, 0);
	SvOOK_off(t);
    }
    tp = SvGROW(t, len + 1);
    return tp;
}

static void
check_align(SV *a, STRLEN size) {
    STRLEN al;
    char *ap = SvPV(a, al);
    if (((IV)ap) & (size - 1))
	SvOOK_off(ap);
    if ((((IV)ap) | al) & (size - 1))
	croak("unaligned packed string (pv offset: %p, pv size: %ld, "
	      "required alignment: %ld)", ap, (long)al, (long)size);
}

MODULE = Math::Packed		PACKAGE = Math::Packed		

void
_mp_bitop(a, b, t = a)
    SV *a
    SV *b
    SV *t
ALIAS:
    mp_and = BITOP_AND
    mp_or = BITOP_OR
    mp_xor = BITOP_XOR
    mp_neqv = BITOP_XOR
    mp_imp = BITOP_IMP
    mp_pmi = BITOP_PMI
    mp_nand = BITOP_NAND
    mp_nor = BITOP_NOR
    mp_eqv = BITOP_NXOR
    mp_nxor = BITOP_NXOR
    mp_nimp = BITOP_NIMP
    mp_npmi = BITOP_NPMI
CODE:
{
    void (*uv_bitop)(UV *, UV *, UV *, UV *);
    void (*char_bitop)(char *, char *, char *, char *);
    STRLEN al, bl, bli;
    char *ap, *bp, *tp, *btop, *btopi;
    UV buffer[64];
    switch (ix) {
    case BITOP_AND:
        uv_bitop = &uv_and;
        char_bitop = &char_and;
        break;
    case BITOP_OR:
        uv_bitop = &uv_or;
        char_bitop = &char_or;
        break;
    case BITOP_XOR:
        uv_bitop = &uv_xor;
        char_bitop = &char_xor;
        break;
    case BITOP_IMP:
        uv_bitop = &uv_imp;
        char_bitop = &char_imp;
        break;
    case BITOP_PMI:
        uv_bitop = &uv_pmi;
        char_bitop = &char_pmi;
        break;

    case BITOP_NAND:
        uv_bitop = &uv_and;
        char_bitop = &char_and;
        break;
    case BITOP_NOR:
        uv_bitop = &uv_or;
        char_bitop = &char_or;
        break;
    case BITOP_NXOR:
        uv_bitop = &uv_xor;
        char_bitop = &char_xor;
        break;
    case BITOP_NIMP:
        uv_bitop = &uv_nimp;
        char_bitop = &char_nimp;
        break;
    case BITOP_NPMI:
        uv_bitop = &uv_npmi;
        char_bitop = &char_npmi;
        break;

    default:
        croak("bitop %d not implemented yet!", ix);
    }

    al = SvCUR(a);
    if (!al) {
	sv_setpvn(t, "", 0);
	return;
    }
    bl = SvCUR(b);
    if (!bl) croak("length of secondary argument is zero");
    tp = make_dest(t, al, t != a && t != b);
    ap = SvPV_nolen(a);
    bp = SvPV_nolen(b);

    if (bl < al) {
	STRLEN n =  (sizeof(buffer) < al + bl ? sizeof(buffer) : al + bl) / bl;
	if (n > 1) {
	    char *p = (char *)buffer;
	    STRLEN i;
	    for (i = 0; i < n; i++, p += bl)
		memcpy(p, bp, bl);
	    bp = (char *)buffer;
	    bl *= n;
	}
	else if (t == b) {
	    bp = savepvn(bp, bl);
	    save_freepv(bp);
	}
    }
    if (bl <= al) goto set_top;

    while (1) {
        /* fprintf(stderr, "bl: %ld, al: %ld, bli: %ld, ap: %p, bp: %p, tp: %p, btop: %p, btopi: %p\n",
           bl, al, bli, ap, bp, tp, btop, btopi); */
        if (bl > al) {
            bl = al;
          set_top:
            btop = bp + bl;
            bli = bl & ~(sizeof(UV) - 1);
            btopi = bp + bli;
        }
        if (((UV)ap | (UV)bp | (UV)tp) & (sizeof(UV) - 1))
            (*char_bitop)(ap, bp, tp, btop);
        else {
            (*uv_bitop)((UV*)ap, (UV*)bp, (UV*)tp, (UV*)btopi);
            if (bli < bl)
                (*char_bitop)(ap + bli, bp + bli, tp + bli, btop);
        }
        al -= bl;
        ap += bl;
        tp += bl;
        if (!al) break;
    }
    SvPOK_on(t);
    SvCUR_set(t, al);
    *tp = '\0';
}

void
mp_bvgrep(packer, a, bv, t = a)
    char packer
    SV *a
    SV *bv
    SV *t
CODE:
{
    STRLEN bvl, al, tl, size, aoff, toff;
    char *bvp = SvPV(bv, bvl);
    vtable *vt;

    vt = find_vtable(packer);
    size = vt->size;

    if (t == bv) {
	bvp = savepvn(bvp, bl);
	save_freepv(bvp);
    }
    check_alignment(a, size);
    al = SvCUR(a);
    tl = ((al / size) > (8 << 3) ? (al / size) >> 3 : 8) * size;

    make_dest(t, tl, t != a);
    check_alignment(t, size);

    while (1) {
	char *tp = SvPVX(t);
	char *ap = SvPV_nolen(a);
	char *acp = ap + aoff;
	char *tcp = tp + toff;
	(*vt->bvgrep)(&acp, bvp, &tcp, ap + al, bvl, tp + tl);
	aoff = acp - ap;
	toff = tcp - tp;
	if (aoff < al) {
	    tl *= 2;
	    if (tl > al) tl = al;
	    SvGROW(t, tl + 1);
	}
	else {
	    
	    SvCUR_set(
	}
    }
}
