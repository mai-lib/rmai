/* ALTREP vectors backed by mai's raw binary vector files.
 *
 * mai's write_vec() writes a vector's elements as they sit in memory:
 * doubles as 8 bytes, ints as 4, booleans as 1 (0, 1, or 255 for NA).
 * Instead of reading such a file into a new R vector, rmai maps it and
 * hands R an ALTREP vector over the mapping.
 *
 * - int: the bytes are already an R integer vector (NA is INT_MIN in both).
 * - double: mai's NA is a NaN with payload 0xdeadbeef, R's has 1954. Elt()
 *   and Get_region() translate on the fly; the first Dataptr() rewrites
 *   NAs in place. The mapping is private, so that never touches the file.
 * - boolean: 1 byte per element against R's 4, so Dataptr() materialises
 *   an R logical vector into data2; Elt() reads the bytes until then.
 *
 * Where R provides it (R_ALTREP_HAS_EXTRACT_ARRAY_SUBSET, from the
 * array-subset variant in github.com/mdsumner/r-variants), x[i, j, ...]
 * is answered in one call instead of one Elt() per element.
 *
 * When rmai embeds mai as a library, the mapping can be replaced by mai's
 * own buffer and the R-facing side stays the same.
 */

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Altrep.h>
#include <R_ext/Rdynload.h>

#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#ifndef _WIN32
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#endif

enum { MAI_DOUBLE = 0, MAI_INT = 1, MAI_BOOLEAN = 2 };

static const size_t eltsz[] = { 8, 4, 1 };
static const uint64_t mai_na_bits = UINT64_C(0x7ff80000deadbeef);

typedef struct {
    int type;
    R_xlen_t n;
    void *elts;      /* mapping, or malloc'd copy where mmap is unavailable */
    size_t size;
    int mapped;
    int na_fixed;    /* double: mai NAs already rewritten as R NAs */
    /* counters, for tests and for seeing what R asks for */
    double n_elt, n_region, n_dataptr, n_array_subset;
} mai_vec_t;

static R_altrep_class_t mai_dbl_class, mai_int_class, mai_lgl_class;

static mai_vec_t *vec_of(SEXP x)
{
    mai_vec_t *v = R_ExternalPtrAddr(R_altrep_data1(x));
    if (!v)
        Rf_error("rmai: mai vector has been released");
    return v;
}

static void vec_finalize(SEXP ptr)
{
    mai_vec_t *v = R_ExternalPtrAddr(ptr);
    if (!v)
        return;
#ifndef _WIN32
    if (v->mapped)
        munmap(v->elts, v->size);
    else
#endif
        free(v->elts);
    free(v);
    R_ClearExternalPtr(ptr);
}

static inline double dbl_get(const mai_vec_t *v, R_xlen_t i)
{
    double d = ((const double *)v->elts)[i];
    if (!v->na_fixed && ISNAN(d)) {
        uint64_t bits;
        memcpy(&bits, &d, sizeof bits);
        if (bits == mai_na_bits)
            return NA_REAL;
    }
    return d;
}

static inline int lgl_get(const mai_vec_t *v, R_xlen_t i)
{
    uint8_t b = ((const uint8_t *)v->elts)[i];
    return b == 255 ? NA_LOGICAL : b != 0;
}

static void fix_dbl_na(mai_vec_t *v)
{
    if (v->na_fixed)
        return;
    double *d = v->elts;
    for (R_xlen_t i = 0; i < v->n; i++)
        if (ISNAN(d[i])) {
            uint64_t bits;
            memcpy(&bits, &d[i], sizeof bits);
            if (bits == mai_na_bits)
                d[i] = NA_REAL;
        }
    v->na_fixed = 1;
}

/* ALTREP methods common to all three classes */

static R_xlen_t vec_Length(SEXP x) { return vec_of(x)->n; }

static Rboolean vec_Inspect(SEXP x, int pre, int deep, int pvec,
                            void (*inspect_subtree)(SEXP, int, int, int))
{
    mai_vec_t *v = vec_of(x);
    static const char *tname[] = { "double", "int", "boolean" };
    Rprintf(" mai vector(%s) [%s, %s]\n", tname[v->type],
            v->mapped ? "mapped" : "copied",
            R_altrep_data2(x) != R_NilValue ? "materialised" : "raw");
    return TRUE;
}

static void *vec_Dataptr(SEXP x, Rboolean writeable)
{
    mai_vec_t *v = vec_of(x);
    v->n_dataptr++;
    switch (v->type) {
    case MAI_DOUBLE:
        fix_dbl_na(v);
        return v->elts;
    case MAI_INT:
        return v->elts;
    default: {
        SEXP m = R_altrep_data2(x);
        if (m == R_NilValue) {
            m = PROTECT(Rf_allocVector(LGLSXP, v->n));
            int *p = LOGICAL(m);
            for (R_xlen_t i = 0; i < v->n; i++)
                p[i] = lgl_get(v, i);
            R_set_altrep_data2(x, m);
            UNPROTECT(1);
        }
        return LOGICAL(m);
    }
    }
}

static const void *vec_Dataptr_or_null(SEXP x)
{
    mai_vec_t *v = vec_of(x);
    switch (v->type) {
    case MAI_DOUBLE:
        return v->na_fixed ? v->elts : NULL;
    case MAI_INT:
        return v->elts;
    default: {
        SEXP m = R_altrep_data2(x);
        return m == R_NilValue ? NULL : LOGICAL(m);
    }
    }
}

/* Typed element access */

static double dbl_Elt(SEXP x, R_xlen_t i)
{
    mai_vec_t *v = vec_of(x);
    v->n_elt++;
    return dbl_get(v, i);
}

static R_xlen_t dbl_Get_region(SEXP x, R_xlen_t i, R_xlen_t n, double *buf)
{
    mai_vec_t *v = vec_of(x);
    v->n_region++;
    R_xlen_t k = (i + n > v->n) ? v->n - i : n;
    for (R_xlen_t j = 0; j < k; j++)
        buf[j] = dbl_get(v, i + j);
    return k;
}

static int int_Elt(SEXP x, R_xlen_t i)
{
    mai_vec_t *v = vec_of(x);
    v->n_elt++;
    return ((const int *)v->elts)[i];
}

static R_xlen_t int_Get_region(SEXP x, R_xlen_t i, R_xlen_t n, int *buf)
{
    mai_vec_t *v = vec_of(x);
    v->n_region++;
    R_xlen_t k = (i + n > v->n) ? v->n - i : n;
    memcpy(buf, (const int *)v->elts + i, k * sizeof(int));
    return k;
}

static int lgl_Elt(SEXP x, R_xlen_t i)
{
    mai_vec_t *v = vec_of(x);
    v->n_elt++;
    SEXP m = R_altrep_data2(x);
    return m != R_NilValue ? LOGICAL(m)[i] : lgl_get(v, i);
}

static R_xlen_t lgl_Get_region(SEXP x, R_xlen_t i, R_xlen_t n, int *buf)
{
    mai_vec_t *v = vec_of(x);
    v->n_region++;
    R_xlen_t k = (i + n > v->n) ? v->n - i : n;
    SEXP m = R_altrep_data2(x);
    for (R_xlen_t j = 0; j < k; j++)
        buf[j] = m != R_NilValue ? LOGICAL(m)[i + j] : lgl_get(v, i + j);
    return k;
}

#ifdef R_ALTREP_HAS_EXTRACT_ARRAY_SUBSET
/* x[i, j, ...]: walk the output in column-major order, reading each
   element straight from the mapping. 'subs' holds 1-based in-range
   indices or NA, already checked by R. */
static SEXP vec_Extract_array_subset(SEXP x, SEXP subs, SEXP dim, SEXP call)
{
    mai_vec_t *v = vec_of(x);
    /* after a boolean materialises, writes may live in data2 only */
    if (v->type == MAI_BOOLEAN && R_altrep_data2(x) != R_NilValue)
        return NULL;
    v->n_array_subset++;

    int k = LENGTH(subs);
    const int *pdim = INTEGER(dim);
    R_xlen_t n = 1;
    for (int d = 0; d < k; d++)
        n *= XLENGTH(VECTOR_ELT(subs, d));

    const int **s = (const int **)R_alloc(k, sizeof(int *));
    R_xlen_t *len = (R_xlen_t *)R_alloc(k, sizeof(R_xlen_t));
    R_xlen_t *stride = (R_xlen_t *)R_alloc(k, sizeof(R_xlen_t));
    R_xlen_t *pos = (R_xlen_t *)R_alloc(k, sizeof(R_xlen_t));
    R_xlen_t st = 1;
    for (int d = 0; d < k; d++) {
        s[d] = INTEGER(VECTOR_ELT(subs, d));
        len[d] = XLENGTH(VECTOR_ELT(subs, d));
        stride[d] = st;
        st *= pdim[d];
        pos[d] = 0;
    }

    SEXPTYPE type = v->type == MAI_DOUBLE ? REALSXP
        : v->type == MAI_INT ? INTSXP : LGLSXP;
    SEXP ans = PROTECT(Rf_allocVector(type, n));
    double *pd = type == REALSXP ? REAL(ans) : NULL;
    int *pi = type == REALSXP ? NULL : (type == INTSXP ? INTEGER(ans) : LOGICAL(ans));

    for (R_xlen_t o = 0; o < n; o++) {
        R_xlen_t off = 0;
        int na = 0;
        for (int d = 0; d < k; d++) {
            int idx = s[d][pos[d]];
            if (idx == NA_INTEGER) { na = 1; break; }
            off += (R_xlen_t)(idx - 1) * stride[d];
        }
        switch (v->type) {
        case MAI_DOUBLE:  pd[o] = na ? NA_REAL : dbl_get(v, off); break;
        case MAI_INT:     pi[o] = na ? NA_INTEGER : ((const int *)v->elts)[off]; break;
        default:          pi[o] = na ? NA_LOGICAL : lgl_get(v, off); break;
        }
        /* odometer */
        for (int d = 0; d < k; d++) {
            if (++pos[d] < len[d]) break;
            pos[d] = 0;
        }
    }
    UNPROTECT(1);
    return ans;
}
#endif

/* Construction */

static void *read_file(const char *path, size_t size, int *mapped)
{
#ifndef _WIN32
    int fd = open(path, O_RDONLY);
    if (fd < 0)
        Rf_error("rmai: can't open '%s'", path);
    void *p = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_PRIVATE, fd, 0);
    close(fd);
    if (p == MAP_FAILED)
        Rf_error("rmai: can't map '%s'", path);
    *mapped = 1;
    return p;
#else
    FILE *fp = fopen(path, "rb");
    if (!fp)
        Rf_error("rmai: can't open '%s'", path);
    void *p = malloc(size);
    if (!p) { fclose(fp); Rf_error("rmai: out of memory"); }
    size_t got = fread(p, 1, size, fp);
    fclose(fp);
    if (got != size) { free(p); Rf_error("rmai: short read on '%s'", path); }
    *mapped = 0;
    return p;
#endif
}

/* .Call(rmai_vec_from_file, path, type, dim)
   type: 0 double, 1 int, 2 boolean. dim: NULL or an integer vector. */
SEXP rmai_vec_from_file(SEXP path, SEXP type, SEXP dim)
{
    const char *p = CHAR(STRING_ELT(path, 0));
    int t = Rf_asInteger(type);
    if (t < 0 || t > 2)
        Rf_error("rmai: bad element type");

    size_t size;
#ifndef _WIN32
    struct stat sb;
    if (stat(p, &sb) != 0)
        Rf_error("rmai: can't stat '%s'", p);
    size = (size_t)sb.st_size;
#else
    FILE *fp = fopen(p, "rb");
    if (!fp) Rf_error("rmai: can't open '%s'", p);
    fseek(fp, 0, SEEK_END);
    size = (size_t)ftell(fp);
    fclose(fp);
#endif
    if (size % eltsz[t] != 0)
        Rf_error("rmai: '%s' is not a whole number of elements", p);
    R_xlen_t n = (R_xlen_t)(size / eltsz[t]);

    SEXP ans;
    if (n == 0) {
        ans = PROTECT(Rf_allocVector(t == MAI_DOUBLE ? REALSXP
                                     : t == MAI_INT ? INTSXP : LGLSXP, 0));
    } else {
        mai_vec_t *v = calloc(1, sizeof *v);
        if (!v)
            Rf_error("rmai: out of memory");
        v->type = t;
        v->n = n;
        v->size = size;
        v->na_fixed = (t != MAI_DOUBLE);
        SEXP ptr = PROTECT(R_MakeExternalPtr(v, R_NilValue, R_NilValue));
        R_RegisterCFinalizerEx(ptr, vec_finalize, TRUE);
        v->elts = read_file(p, size, &v->mapped);
        R_altrep_class_t cls = t == MAI_DOUBLE ? mai_dbl_class
            : t == MAI_INT ? mai_int_class : mai_lgl_class;
        ans = R_new_altrep(cls, ptr, R_NilValue);
        UNPROTECT(1);
        PROTECT(ans);
    }
    if (dim != R_NilValue)
        Rf_setAttrib(ans, R_DimSymbol, Rf_coerceVector(dim, INTSXP));
    UNPROTECT(1);
    return ans;
}

/* .Call(rmai_vec_info, x): NULL for anything that isn't a mai vector */
SEXP rmai_vec_info(SEXP x)
{
    if (!ALTREP(x) || !(R_altrep_inherits(x, mai_dbl_class)
                        || R_altrep_inherits(x, mai_int_class)
                        || R_altrep_inherits(x, mai_lgl_class)))
        return R_NilValue;
    mai_vec_t *v = vec_of(x);
    const char *nm[] = { "mapped", "elt", "region", "dataptr",
                         "array_subset", "" };
    SEXP ans = PROTECT(Rf_mkNamed(VECSXP, nm));
    SET_VECTOR_ELT(ans, 0, Rf_ScalarLogical(v->mapped));
    SET_VECTOR_ELT(ans, 1, Rf_ScalarReal(v->n_elt));
    SET_VECTOR_ELT(ans, 2, Rf_ScalarReal(v->n_region));
    SET_VECTOR_ELT(ans, 3, Rf_ScalarReal(v->n_dataptr));
    SET_VECTOR_ELT(ans, 4, Rf_ScalarReal(v->n_array_subset));
    UNPROTECT(1);
    return ans;
}

SEXP rmai_has_array_subset(void)
{
#ifdef R_ALTREP_HAS_EXTRACT_ARRAY_SUBSET
    return Rf_ScalarLogical(TRUE);
#else
    return Rf_ScalarLogical(FALSE);
#endif
}

static void set_common(R_altrep_class_t cls)
{
    R_set_altrep_Length_method(cls, vec_Length);
    R_set_altrep_Inspect_method(cls, vec_Inspect);
    R_set_altvec_Dataptr_method(cls, vec_Dataptr);
    R_set_altvec_Dataptr_or_null_method(cls, vec_Dataptr_or_null);
#ifdef R_ALTREP_HAS_EXTRACT_ARRAY_SUBSET
    R_set_altvec_Extract_array_subset_method(cls, vec_Extract_array_subset);
#endif
}

static const R_CallMethodDef call_methods[] = {
    { "rmai_vec_from_file", (DL_FUNC)&rmai_vec_from_file, 3 },
    { "rmai_vec_info", (DL_FUNC)&rmai_vec_info, 1 },
    { "rmai_has_array_subset", (DL_FUNC)&rmai_has_array_subset, 0 },
    { NULL, NULL, 0 }
};

void R_init_rmai(DllInfo *dll)
{
    mai_dbl_class = R_make_altreal_class("mai_dbl", "rmai", dll);
    set_common(mai_dbl_class);
    R_set_altreal_Elt_method(mai_dbl_class, dbl_Elt);
    R_set_altreal_Get_region_method(mai_dbl_class, dbl_Get_region);

    mai_int_class = R_make_altinteger_class("mai_int", "rmai", dll);
    set_common(mai_int_class);
    R_set_altinteger_Elt_method(mai_int_class, int_Elt);
    R_set_altinteger_Get_region_method(mai_int_class, int_Get_region);

    mai_lgl_class = R_make_altlogical_class("mai_lgl", "rmai", dll);
    set_common(mai_lgl_class);
    R_set_altlogical_Elt_method(mai_lgl_class, lgl_Elt);
    R_set_altlogical_Get_region_method(mai_lgl_class, lgl_Get_region);

    R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
