/*
*  pgo_xxHash - Fast Hash algorithm
*  Copyright (C) 2012-2016, Yann Collet
*
*  BSD 2-Clause License (http://www.opensource.org/licenses/bsd-license.php)
*
*  Redistribution and use in source and binary forms, with or without
*  modification, are permitted provided that the following conditions are
*  met:
*
*  * Redistributions of source code must retain the above copyright
*  notice, this list of conditions and the following disclaimer.
*  * Redistributions in binary form must reproduce the above
*  copyright notice, this list of conditions and the following disclaimer
*  in the documentation and/or other materials provided with the
*  distribution.
*
*  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
*  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
*  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
*  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
*  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
*  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
*  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
*  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
*  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
*  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
*  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
*  You can contact the author at :
*  - pgo_xxHash homepage: http://www.xxhash.com
*  - pgo_xxHash source repository : https://github.com/Cyan4973/xxHash
*/


/* *************************************
*  Tuning parameters
***************************************/
/*!pgo_XXH_FORCE_MEMORY_ACCESS :
 * By default, access to unaligned memory is controlled by `memcpy()`, which is safe and portable.
 * Unfortunately, on some target/compiler combinations, the generated assembly is sub-optimal.
 * The below switch allow to select different access method for improved performance.
 * Method 0 (default) : use `memcpy()`. Safe and portable.
 * Method 1 : `__packed` statement. It depends on compiler extension (ie, not portable).
 *            This method is safe if your compiler supports it, and *generally* as fast or faster than `memcpy`.
 * Method 2 : direct access. This method doesn't depend on compiler but violate C standard.
 *            It can generate buggy code on targets which do not support unaligned memory accesses.
 *            But in some circumstances, it's the only known way to get the most performance (ie GCC + ARMv6)
 * See http://stackoverflow.com/a/32095106/646947 for details.
 * Prefer these methods in priority order (0 > 1 > 2)
 */
#ifndef pgo_XXH_FORCE_MEMORY_ACCESS   /* can be defined externally, on command line for example */
#  if defined(__GNUC__) && ( defined(__ARM_ARCH_6__) || defined(__ARM_ARCH_6J__) || defined(__ARM_ARCH_6K__) || defined(__ARM_ARCH_6Z__) || defined(__ARM_ARCH_6ZK__) || defined(__ARM_ARCH_6T2__) )
#    define pgo_XXH_FORCE_MEMORY_ACCESS 2
#  elif defined(__INTEL_COMPILER) || \
  (defined(__GNUC__) && ( defined(__ARM_ARCH_7__) || defined(__ARM_ARCH_7A__) || defined(__ARM_ARCH_7R__) || defined(__ARM_ARCH_7M__) || defined(__ARM_ARCH_7S__) ))
#    define pgo_XXH_FORCE_MEMORY_ACCESS 1
#  endif
#endif

/*!pgo_XXH_ACCEPT_NULL_INPUT_POINTER :
 * If the input pointer is a null pointer, pgo_xxHash default behavior is to trigger a memory access error, since it is a bad pointer.
 * When this option is enabled, pgo_xxHash output for null input pointers will be the same as a null-length input.
 * By default, this option is disabled. To enable it, uncomment below define :
 */
/* #define pgo_XXH_ACCEPT_NULL_INPUT_POINTER 1 */

/*!pgo_XXH_FORCE_NATIVE_FORMAT :
 * By default, pgo_xxHash library provides endian-independant Hash values, based on little-endian convention.
 * Results are therefore identical for little-endian and big-endian CPU.
 * This comes at a performance cost for big-endian CPU, since some swapping is required to emulate little-endian format.
 * Should endian-independance be of no importance for your application, you may set the #define below to 1,
 * to improve speed for Big-endian CPU.
 * This option has no impact on Little_Endian CPU.
 */
#ifndef pgo_XXH_FORCE_NATIVE_FORMAT   /* can be defined externally */
#  define pgo_XXH_FORCE_NATIVE_FORMAT 0
#endif

/*!pgo_XXH_FORCE_ALIGN_CHECK :
 * This is a minor performance trick, only useful with lots of very small keys.
 * It means : check for aligned/unaligned input.
 * The check costs one initial branch per hash; set to 0 when the input data
 * is guaranteed to be aligned.
 */
#ifndef pgo_XXH_FORCE_ALIGN_CHECK /* can be defined externally */
#  if defined(__i386) || defined(_M_IX86) || defined(__x86_64__) || defined(_M_X64)
#    define pgo_XXH_FORCE_ALIGN_CHECK 0
#  else
#    define pgo_XXH_FORCE_ALIGN_CHECK 1
#  endif
#endif


/* *************************************
*  Includes & Memory related functions
***************************************/
/* Modify the local functions below should you wish to use some other memory routines */
/* for malloc(), free() */
#include <stdlib.h>
static void* pgo_XXH_malloc(size_t s) { return malloc(s); }
static void  pgo_XXH_free  (void* p)  { free(p); }
/* for memcpy() */
#include <string.h>
static void* pgo_XXH_memcpy(void* dest, const void* src, size_t size) { return memcpy(dest,src,size); }

#define pgo_XXH_STATIC_LINKING_ONLY
#include "pgo_xxhash.h"


/* *************************************
*  Compiler Specific Options
***************************************/
#ifdef _MSC_VER    /* Visual Studio */
#  pragma warning(disable : 4127)      /* disable: C4127: conditional expression is constant */
#  define FORCE_INLINE static __forceinline
#else
#  if defined (__STDC_VERSION__) && __STDC_VERSION__ >= 199901L   /* C99 */
#    ifdef __GNUC__
#      define FORCE_INLINE static inline __attribute__((always_inline))
#    else
#      define FORCE_INLINE static inline
#    endif
#  else
#    define FORCE_INLINE static
#  endif /* __STDC_VERSION__ */
#endif


/* *************************************
*  Basic Types
***************************************/
#ifndef MEM_MODULE
# define MEM_MODULE
# if defined (__STDC_VERSION__) && __STDC_VERSION__ >= 199901L   /* C99 */
#   include <stdint.h>
    typedef uint8_t  BYTE;
    typedef uint16_t U16;
    typedef uint32_t U32;
    typedef  int32_t S32;
    typedef uint64_t U64;
#  else
    typedef unsigned char      BYTE;
    typedef unsigned short     U16;
    typedef unsigned int       U32;
    typedef   signed int       S32;
    typedef unsigned long long U64;
#  endif
#endif


#if (defined(pgo_XXH_FORCE_MEMORY_ACCESS) && (pgo_XXH_FORCE_MEMORY_ACCESS==2))

/* Force direct memory access. Only works on CPU which support unaligned memory access in hardware */
static U32 pgo_XXH_read32(const void* memPtr) { return *(const U32*) memPtr; }
static U64 pgo_XXH_read64(const void* memPtr) { return *(const U64*) memPtr; }

#elif (defined(pgo_XXH_FORCE_MEMORY_ACCESS) && (pgo_XXH_FORCE_MEMORY_ACCESS==1))

/* __pack instructions are safer, but compiler specific, hence potentially problematic for some compilers */
/* currently only defined for gcc and icc */
typedef union { U32 u32; U64 u64; } __attribute__((packed)) unalign;

static U32 pgo_XXH_read32(const void* ptr) { return ((const unalign*)ptr)->u32; }
static U64 pgo_XXH_read64(const void* ptr) { return ((const unalign*)ptr)->u64; }

#else

/* portable and safe solution. Generally efficient.
 * see : http://stackoverflow.com/a/32095106/646947
 */

static U32 pgo_XXH_read32(const void* memPtr)
{
    U32 val;
    memcpy(&val, memPtr, sizeof(val));
    return val;
}

static U64 pgo_XXH_read64(const void* memPtr)
{
    U64 val;
    memcpy(&val, memPtr, sizeof(val));
    return val;
}

#endif   /* pgo_XXH_FORCE_DIRECT_MEMORY_ACCESS */


/* ****************************************
*  Compiler-specific Functions and Macros
******************************************/
#define GCC_VERSION (__GNUC__ * 100 + __GNUC_MINOR__)

/* Note : although _rotl exists for minGW (GCC under windows), performance seems poor */
#if defined(_MSC_VER)
#  define pgo_XXH_rotl32(x,r) _rotl(x,r)
#  define pgo_XXH_rotl64(x,r) _rotl64(x,r)
#else
#  define pgo_XXH_rotl32(x,r) ((x << r) | (x >> (32 - r)))
#  define pgo_XXH_rotl64(x,r) ((x << r) | (x >> (64 - r)))
#endif

#if defined(_MSC_VER)     /* Visual Studio */
#  define pgo_XXH_swap32 _byteswap_ulong
#  define pgo_XXH_swap64 _byteswap_uint64
#elif GCC_VERSION >= 403
#  define pgo_XXH_swap32 __builtin_bswap32
#  define pgo_XXH_swap64 __builtin_bswap64
#else
static U32 pgo_XXH_swap32 (U32 x)
{
    return  ((x << 24) & 0xff000000 ) |
            ((x <<  8) & 0x00ff0000 ) |
            ((x >>  8) & 0x0000ff00 ) |
            ((x >> 24) & 0x000000ff );
}
static U64 pgo_XXH_swap64 (U64 x)
{
    return  ((x << 56) & 0xff00000000000000ULL) |
            ((x << 40) & 0x00ff000000000000ULL) |
            ((x << 24) & 0x0000ff0000000000ULL) |
            ((x << 8)  & 0x000000ff00000000ULL) |
            ((x >> 8)  & 0x00000000ff000000ULL) |
            ((x >> 24) & 0x0000000000ff0000ULL) |
            ((x >> 40) & 0x000000000000ff00ULL) |
            ((x >> 56) & 0x00000000000000ffULL);
}
#endif


/* *************************************
*  Architecture Macros
***************************************/
typedef enum { pgo_XXH_bigEndian=0, pgo_XXH_littleEndian=1 } pgo_XXH_endianess;

/* pgo_XXH_CPU_LITTLE_ENDIAN can be defined externally, for example on the compiler command line */
#ifndef pgo_XXH_CPU_LITTLE_ENDIAN
    static const int g_one = 1;
#   define pgo_XXH_CPU_LITTLE_ENDIAN   (*(const char*)(&g_one))
#endif


/* ***************************
*  Memory reads
*****************************/
typedef enum { pgo_XXH_aligned, pgo_XXH_unaligned } pgo_XXH_alignment;

FORCE_INLINE U32 pgo_XXH_readLE32_align(const void* ptr, pgo_XXH_endianess endian, pgo_XXH_alignment align)
{
    if (align==pgo_XXH_unaligned)
        return endian==pgo_XXH_littleEndian ? pgo_XXH_read32(ptr) : pgo_XXH_swap32(pgo_XXH_read32(ptr));
    else
        return endian==pgo_XXH_littleEndian ? *(const U32*)ptr : pgo_XXH_swap32(*(const U32*)ptr);
}

FORCE_INLINE U32 pgo_XXH_readLE32(const void* ptr, pgo_XXH_endianess endian)
{
    return pgo_XXH_readLE32_align(ptr, endian, pgo_XXH_unaligned);
}

static U32 pgo_XXH_readBE32(const void* ptr)
{
    return pgo_XXH_CPU_LITTLE_ENDIAN ? pgo_XXH_swap32(pgo_XXH_read32(ptr)) : pgo_XXH_read32(ptr);
}

FORCE_INLINE U64 pgo_XXH_readLE64_align(const void* ptr, pgo_XXH_endianess endian, pgo_XXH_alignment align)
{
    if (align==pgo_XXH_unaligned)
        return endian==pgo_XXH_littleEndian ? pgo_XXH_read64(ptr) : pgo_XXH_swap64(pgo_XXH_read64(ptr));
    else
        return endian==pgo_XXH_littleEndian ? *(const U64*)ptr : pgo_XXH_swap64(*(const U64*)ptr);
}

FORCE_INLINE U64 pgo_XXH_readLE64(const void* ptr, pgo_XXH_endianess endian)
{
    return pgo_XXH_readLE64_align(ptr, endian, pgo_XXH_unaligned);
}

static U64 pgo_XXH_readBE64(const void* ptr)
{
    return pgo_XXH_CPU_LITTLE_ENDIAN ? pgo_XXH_swap64(pgo_XXH_read64(ptr)) : pgo_XXH_read64(ptr);
}


/* *************************************
*  Macros
***************************************/
#define pgo_XXH_STATIC_ASSERT(c)   { enum { pgo_XXH_static_assert = 1/(int)(!!(c)) }; }    /* use only *after* variable declarations */


/* *************************************
*  Constants
***************************************/
static const U32 PRIME32_1 = 2654435761U;
static const U32 PRIME32_2 = 2246822519U;
static const U32 PRIME32_3 = 3266489917U;
static const U32 PRIME32_4 =  668265263U;
static const U32 PRIME32_5 =  374761393U;

static const U64 PRIME64_1 = 11400714785074694791ULL;
static const U64 PRIME64_2 = 14029467366897019727ULL;
static const U64 PRIME64_3 =  1609587929392839161ULL;
static const U64 PRIME64_4 =  9650029242287828579ULL;
static const U64 PRIME64_5 =  2870177450012600261ULL;

pgo_XXH_PUBLIC_API unsigned pgo_XXH_versionNumber (void) { return pgo_XXH_VERSION_NUMBER; }


/* **************************
*  Utils
****************************/
pgo_XXH_PUBLIC_API void pgo_XXH32_copyState(pgo_XXH32_state_t* restrict dstState, const pgo_XXH32_state_t* restrict srcState)
{
    memcpy(dstState, srcState, sizeof(*dstState));
}

pgo_XXH_PUBLIC_API void pgo_XXH64_copyState(pgo_XXH64_state_t* restrict dstState, const pgo_XXH64_state_t* restrict srcState)
{
    memcpy(dstState, srcState, sizeof(*dstState));
}


/* ***************************
*  Simple Hash Functions
*****************************/

static U32 pgo_XXH32_round(U32 seed, U32 input)
{
    seed += input * PRIME32_2;
    seed  = pgo_XXH_rotl32(seed, 13);
    seed *= PRIME32_1;
    return seed;
}

FORCE_INLINE U32 pgo_XXH32_endian_align(const void* input, size_t len, U32 seed, pgo_XXH_endianess endian, pgo_XXH_alignment align)
{
    const BYTE* p = (const BYTE*)input;
    const BYTE* bEnd = p + len;
    U32 h32;
#define pgo_XXH_get32bits(p) pgo_XXH_readLE32_align(p, endian, align)

#ifdef pgo_XXH_ACCEPT_NULL_INPUT_POINTER
    if (p==NULL) {
        len=0;
        bEnd=p=(const BYTE*)(size_t)16;
    }
#endif

    if (len>=16) {
        const BYTE* const limit = bEnd - 16;
        U32 v1 = seed + PRIME32_1 + PRIME32_2;
        U32 v2 = seed + PRIME32_2;
        U32 v3 = seed + 0;
        U32 v4 = seed - PRIME32_1;

        do {
            v1 = pgo_XXH32_round(v1, pgo_XXH_get32bits(p)); p+=4;
            v2 = pgo_XXH32_round(v2, pgo_XXH_get32bits(p)); p+=4;
            v3 = pgo_XXH32_round(v3, pgo_XXH_get32bits(p)); p+=4;
            v4 = pgo_XXH32_round(v4, pgo_XXH_get32bits(p)); p+=4;
        } while (p<=limit);

        h32 = pgo_XXH_rotl32(v1, 1) + pgo_XXH_rotl32(v2, 7) + pgo_XXH_rotl32(v3, 12) + pgo_XXH_rotl32(v4, 18);
    } else {
        h32  = seed + PRIME32_5;
    }

    h32 += (U32) len;

    while (p+4<=bEnd) {
        h32 += pgo_XXH_get32bits(p) * PRIME32_3;
        h32  = pgo_XXH_rotl32(h32, 17) * PRIME32_4 ;
        p+=4;
    }

    while (p<bEnd) {
        h32 += (*p) * PRIME32_5;
        h32 = pgo_XXH_rotl32(h32, 11) * PRIME32_1 ;
        p++;
    }

    h32 ^= h32 >> 15;
    h32 *= PRIME32_2;
    h32 ^= h32 >> 13;
    h32 *= PRIME32_3;
    h32 ^= h32 >> 16;

    return h32;
}


pgo_XXH_PUBLIC_API unsigned int pgo_XXH32 (const void* input, size_t len, unsigned int seed)
{
#if 0
    /* Simple version, good for code maintenance, but unfortunately slow for small inputs */
    pgo_XXH32_CREATESTATE_STATIC(state);
    pgo_XXH32_reset(state, seed);
    pgo_XXH32_update(state, input, len);
    return pgo_XXH32_digest(state);
#else
    pgo_XXH_endianess endian_detected = (pgo_XXH_endianess)pgo_XXH_CPU_LITTLE_ENDIAN;

    if (pgo_XXH_FORCE_ALIGN_CHECK) {
        if ((((size_t)input) & 3) == 0) {   /* Input is 4-bytes aligned, leverage the speed benefit */
            if ((endian_detected==pgo_XXH_littleEndian) || pgo_XXH_FORCE_NATIVE_FORMAT)
                return pgo_XXH32_endian_align(input, len, seed, pgo_XXH_littleEndian, pgo_XXH_aligned);
            else
                return pgo_XXH32_endian_align(input, len, seed, pgo_XXH_bigEndian, pgo_XXH_aligned);
    }   }

    if ((endian_detected==pgo_XXH_littleEndian) || pgo_XXH_FORCE_NATIVE_FORMAT)
        return pgo_XXH32_endian_align(input, len, seed, pgo_XXH_littleEndian, pgo_XXH_unaligned);
    else
        return pgo_XXH32_endian_align(input, len, seed, pgo_XXH_bigEndian, pgo_XXH_unaligned);
#endif
}


static U64 pgo_XXH64_round(U64 acc, U64 input)
{
    acc += input * PRIME64_2;
    acc  = pgo_XXH_rotl64(acc, 31);
    acc *= PRIME64_1;
    return acc;
}

static U64 pgo_XXH64_mergeRound(U64 acc, U64 val)
{
    val  = pgo_XXH64_round(0, val);
    acc ^= val;
    acc  = acc * PRIME64_1 + PRIME64_4;
    return acc;
}

FORCE_INLINE U64 pgo_XXH64_endian_align(const void* input, size_t len, U64 seed, pgo_XXH_endianess endian, pgo_XXH_alignment align)
{
    const BYTE* p = (const BYTE*)input;
    const BYTE* const bEnd = p + len;
    U64 h64;
#define pgo_XXH_get64bits(p) pgo_XXH_readLE64_align(p, endian, align)

#ifdef pgo_XXH_ACCEPT_NULL_INPUT_POINTER
    if (p==NULL) {
        len=0;
        bEnd=p=(const BYTE*)(size_t)32;
    }
#endif

    if (len>=32) {
        const BYTE* const limit = bEnd - 32;
        U64 v1 = seed + PRIME64_1 + PRIME64_2;
        U64 v2 = seed + PRIME64_2;
        U64 v3 = seed + 0;
        U64 v4 = seed - PRIME64_1;

        do {
            v1 = pgo_XXH64_round(v1, pgo_XXH_get64bits(p)); p+=8;
            v2 = pgo_XXH64_round(v2, pgo_XXH_get64bits(p)); p+=8;
            v3 = pgo_XXH64_round(v3, pgo_XXH_get64bits(p)); p+=8;
            v4 = pgo_XXH64_round(v4, pgo_XXH_get64bits(p)); p+=8;
        } while (p<=limit);

        h64 = pgo_XXH_rotl64(v1, 1) + pgo_XXH_rotl64(v2, 7) + pgo_XXH_rotl64(v3, 12) + pgo_XXH_rotl64(v4, 18);
        h64 = pgo_XXH64_mergeRound(h64, v1);
        h64 = pgo_XXH64_mergeRound(h64, v2);
        h64 = pgo_XXH64_mergeRound(h64, v3);
        h64 = pgo_XXH64_mergeRound(h64, v4);

    } else {
        h64  = seed + PRIME64_5;
    }

    h64 += (U64) len;

    while (p+8<=bEnd) {
        U64 const k1 = pgo_XXH64_round(0, pgo_XXH_get64bits(p));
        h64 ^= k1;
        h64  = pgo_XXH_rotl64(h64,27) * PRIME64_1 + PRIME64_4;
        p+=8;
    }

    if (p+4<=bEnd) {
        h64 ^= (U64)(pgo_XXH_get32bits(p)) * PRIME64_1;
        h64 = pgo_XXH_rotl64(h64, 23) * PRIME64_2 + PRIME64_3;
        p+=4;
    }

    while (p<bEnd) {
        h64 ^= (*p) * PRIME64_5;
        h64 = pgo_XXH_rotl64(h64, 11) * PRIME64_1;
        p++;
    }

    h64 ^= h64 >> 33;
    h64 *= PRIME64_2;
    h64 ^= h64 >> 29;
    h64 *= PRIME64_3;
    h64 ^= h64 >> 32;

    return h64;
}


pgo_XXH_PUBLIC_API unsigned long long pgo_XXH64 (const void* input, size_t len, unsigned long long seed)
{
#if 0
    /* Simple version, good for code maintenance, but unfortunately slow for small inputs */
    pgo_XXH64_CREATESTATE_STATIC(state);
    pgo_XXH64_reset(state, seed);
    pgo_XXH64_update(state, input, len);
    return pgo_XXH64_digest(state);
#else
    pgo_XXH_endianess endian_detected = (pgo_XXH_endianess)pgo_XXH_CPU_LITTLE_ENDIAN;

    if (pgo_XXH_FORCE_ALIGN_CHECK) {
        if ((((size_t)input) & 7)==0) {  /* Input is aligned, let's leverage the speed advantage */
            if ((endian_detected==pgo_XXH_littleEndian) || pgo_XXH_FORCE_NATIVE_FORMAT)
                return pgo_XXH64_endian_align(input, len, seed, pgo_XXH_littleEndian, pgo_XXH_aligned);
            else
                return pgo_XXH64_endian_align(input, len, seed, pgo_XXH_bigEndian, pgo_XXH_aligned);
    }   }

    if ((endian_detected==pgo_XXH_littleEndian) || pgo_XXH_FORCE_NATIVE_FORMAT)
        return pgo_XXH64_endian_align(input, len, seed, pgo_XXH_littleEndian, pgo_XXH_unaligned);
    else
        return pgo_XXH64_endian_align(input, len, seed, pgo_XXH_bigEndian, pgo_XXH_unaligned);
#endif
}


/* **************************************************
*  Advanced Hash Functions
****************************************************/

pgo_XXH_PUBLIC_API pgo_XXH32_state_t* pgo_XXH32_createState(void)
{
    return (pgo_XXH32_state_t*)pgo_XXH_malloc(sizeof(pgo_XXH32_state_t));
}
pgo_XXH_PUBLIC_API pgo_XXH_errorcode pgo_XXH32_freeState(pgo_XXH32_state_t* statePtr)
{
    pgo_XXH_free(statePtr);
    return pgo_XXH_OK;
}

pgo_XXH_PUBLIC_API pgo_XXH64_state_t* pgo_XXH64_createState(void)
{
    return (pgo_XXH64_state_t*)pgo_XXH_malloc(sizeof(pgo_XXH64_state_t));
}
pgo_XXH_PUBLIC_API pgo_XXH_errorcode pgo_XXH64_freeState(pgo_XXH64_state_t* statePtr)
{
    pgo_XXH_free(statePtr);
    return pgo_XXH_OK;
}


/*** Hash feed ***/

pgo_XXH_PUBLIC_API pgo_XXH_errorcode pgo_XXH32_reset(pgo_XXH32_state_t* statePtr, unsigned int seed)
{
    pgo_XXH32_state_t state;   /* using a local state to memcpy() in order to avoid strict-aliasing warnings */
    memset(&state, 0, sizeof(state));
    state.seed = seed;
    state.v1 = seed + PRIME32_1 + PRIME32_2;
    state.v2 = seed + PRIME32_2;
    state.v3 = seed + 0;
    state.v4 = seed - PRIME32_1;
    memcpy(statePtr, &state, sizeof(state));
    return pgo_XXH_OK;
}


pgo_XXH_PUBLIC_API pgo_XXH_errorcode pgo_XXH64_reset(pgo_XXH64_state_t* statePtr, unsigned long long seed)
{
    pgo_XXH64_state_t state;   /* using a local state to memcpy() in order to avoid strict-aliasing warnings */
    memset(&state, 0, sizeof(state));
    state.seed = seed;
    state.v1 = seed + PRIME64_1 + PRIME64_2;
    state.v2 = seed + PRIME64_2;
    state.v3 = seed + 0;
    state.v4 = seed - PRIME64_1;
    memcpy(statePtr, &state, sizeof(state));
    return pgo_XXH_OK;
}


FORCE_INLINE pgo_XXH_errorcode pgo_XXH32_update_endian (pgo_XXH32_state_t* state, const void* input, size_t len, pgo_XXH_endianess endian)
{
    const BYTE* p = (const BYTE*)input;
    const BYTE* const bEnd = p + len;

#ifdef pgo_XXH_ACCEPT_NULL_INPUT_POINTER
    if (input==NULL) return pgo_XXH_ERROR;
#endif

    state->total_len += len;

    if (state->memsize + len < 16)  {   /* fill in tmp buffer */
        pgo_XXH_memcpy((BYTE*)(state->mem32) + state->memsize, input, len);
        state->memsize += (U32)len;
        return pgo_XXH_OK;
    }

    if (state->memsize) {   /* some data left from previous update */
        pgo_XXH_memcpy((BYTE*)(state->mem32) + state->memsize, input, 16-state->memsize);
        {   const U32* p32 = state->mem32;
            state->v1 = pgo_XXH32_round(state->v1, pgo_XXH_readLE32(p32, endian)); p32++;
            state->v2 = pgo_XXH32_round(state->v2, pgo_XXH_readLE32(p32, endian)); p32++;
            state->v3 = pgo_XXH32_round(state->v3, pgo_XXH_readLE32(p32, endian)); p32++;
            state->v4 = pgo_XXH32_round(state->v4, pgo_XXH_readLE32(p32, endian)); p32++;
        }
        p += 16-state->memsize;
        state->memsize = 0;
    }

    if (p <= bEnd-16) {
        const BYTE* const limit = bEnd - 16;
        U32 v1 = state->v1;
        U32 v2 = state->v2;
        U32 v3 = state->v3;
        U32 v4 = state->v4;

        do {
            v1 = pgo_XXH32_round(v1, pgo_XXH_readLE32(p, endian)); p+=4;
            v2 = pgo_XXH32_round(v2, pgo_XXH_readLE32(p, endian)); p+=4;
            v3 = pgo_XXH32_round(v3, pgo_XXH_readLE32(p, endian)); p+=4;
            v4 = pgo_XXH32_round(v4, pgo_XXH_readLE32(p, endian)); p+=4;
        } while (p<=limit);

        state->v1 = v1;
        state->v2 = v2;
        state->v3 = v3;
        state->v4 = v4;
    }

    if (p < bEnd) {
        pgo_XXH_memcpy(state->mem32, p, bEnd-p);
        state->memsize = (int)(bEnd-p);
    }

    return pgo_XXH_OK;
}

pgo_XXH_PUBLIC_API pgo_XXH_errorcode pgo_XXH32_update (pgo_XXH32_state_t* state_in, const void* input, size_t len)
{
    pgo_XXH_endianess endian_detected = (pgo_XXH_endianess)pgo_XXH_CPU_LITTLE_ENDIAN;

    if ((endian_detected==pgo_XXH_littleEndian) || pgo_XXH_FORCE_NATIVE_FORMAT)
        return pgo_XXH32_update_endian(state_in, input, len, pgo_XXH_littleEndian);
    else
        return pgo_XXH32_update_endian(state_in, input, len, pgo_XXH_bigEndian);
}



FORCE_INLINE U32 pgo_XXH32_digest_endian (const pgo_XXH32_state_t* state, pgo_XXH_endianess endian)
{
    const BYTE * p = (const BYTE*)state->mem32;
    const BYTE* const bEnd = (const BYTE*)(state->mem32) + state->memsize;
    U32 h32;

    if (state->total_len >= 16) {
        h32 = pgo_XXH_rotl32(state->v1, 1) + pgo_XXH_rotl32(state->v2, 7) + pgo_XXH_rotl32(state->v3, 12) + pgo_XXH_rotl32(state->v4, 18);
    } else {
        h32 = state->seed + PRIME32_5;
    }

    h32 += (U32) state->total_len;

    while (p+4<=bEnd) {
        h32 += pgo_XXH_readLE32(p, endian) * PRIME32_3;
        h32  = pgo_XXH_rotl32(h32, 17) * PRIME32_4;
        p+=4;
    }

    while (p<bEnd) {
        h32 += (*p) * PRIME32_5;
        h32  = pgo_XXH_rotl32(h32, 11) * PRIME32_1;
        p++;
    }

    h32 ^= h32 >> 15;
    h32 *= PRIME32_2;
    h32 ^= h32 >> 13;
    h32 *= PRIME32_3;
    h32 ^= h32 >> 16;

    return h32;
}


pgo_XXH_PUBLIC_API unsigned int pgo_XXH32_digest (const pgo_XXH32_state_t* state_in)
{
    pgo_XXH_endianess endian_detected = (pgo_XXH_endianess)pgo_XXH_CPU_LITTLE_ENDIAN;

    if ((endian_detected==pgo_XXH_littleEndian) || pgo_XXH_FORCE_NATIVE_FORMAT)
        return pgo_XXH32_digest_endian(state_in, pgo_XXH_littleEndian);
    else
        return pgo_XXH32_digest_endian(state_in, pgo_XXH_bigEndian);
}



/* **** pgo_XXH64 **** */

FORCE_INLINE pgo_XXH_errorcode pgo_XXH64_update_endian (pgo_XXH64_state_t* state, const void* input, size_t len, pgo_XXH_endianess endian)
{
    const BYTE* p = (const BYTE*)input;
    const BYTE* const bEnd = p + len;

#ifdef pgo_XXH_ACCEPT_NULL_INPUT_POINTER
    if (input==NULL) return pgo_XXH_ERROR;
#endif

    state->total_len += len;

    if (state->memsize + len < 32) {  /* fill in tmp buffer */
        pgo_XXH_memcpy(((BYTE*)state->mem64) + state->memsize, input, len);
        state->memsize += (U32)len;
        return pgo_XXH_OK;
    }

    if (state->memsize) {   /* tmp buffer is full */
        pgo_XXH_memcpy(((BYTE*)state->mem64) + state->memsize, input, 32-state->memsize);
        state->v1 = pgo_XXH64_round(state->v1, pgo_XXH_readLE64(state->mem64+0, endian));
        state->v2 = pgo_XXH64_round(state->v2, pgo_XXH_readLE64(state->mem64+1, endian));
        state->v3 = pgo_XXH64_round(state->v3, pgo_XXH_readLE64(state->mem64+2, endian));
        state->v4 = pgo_XXH64_round(state->v4, pgo_XXH_readLE64(state->mem64+3, endian));
        p += 32-state->memsize;
        state->memsize = 0;
    }

    if (p+32 <= bEnd) {
        const BYTE* const limit = bEnd - 32;
        U64 v1 = state->v1;
        U64 v2 = state->v2;
        U64 v3 = state->v3;
        U64 v4 = state->v4;

        do {
            v1 = pgo_XXH64_round(v1, pgo_XXH_readLE64(p, endian)); p+=8;
            v2 = pgo_XXH64_round(v2, pgo_XXH_readLE64(p, endian)); p+=8;
            v3 = pgo_XXH64_round(v3, pgo_XXH_readLE64(p, endian)); p+=8;
            v4 = pgo_XXH64_round(v4, pgo_XXH_readLE64(p, endian)); p+=8;
        } while (p<=limit);

        state->v1 = v1;
        state->v2 = v2;
        state->v3 = v3;
        state->v4 = v4;
    }

    if (p < bEnd) {
        pgo_XXH_memcpy(state->mem64, p, bEnd-p);
        state->memsize = (int)(bEnd-p);
    }

    return pgo_XXH_OK;
}

pgo_XXH_PUBLIC_API pgo_XXH_errorcode pgo_XXH64_update (pgo_XXH64_state_t* state_in, const void* input, size_t len)
{
    pgo_XXH_endianess endian_detected = (pgo_XXH_endianess)pgo_XXH_CPU_LITTLE_ENDIAN;

    if ((endian_detected==pgo_XXH_littleEndian) || pgo_XXH_FORCE_NATIVE_FORMAT)
        return pgo_XXH64_update_endian(state_in, input, len, pgo_XXH_littleEndian);
    else
        return pgo_XXH64_update_endian(state_in, input, len, pgo_XXH_bigEndian);
}



FORCE_INLINE U64 pgo_XXH64_digest_endian (const pgo_XXH64_state_t* state, pgo_XXH_endianess endian)
{
    const BYTE * p = (const BYTE*)state->mem64;
    const BYTE* const bEnd = (const BYTE*)state->mem64 + state->memsize;
    U64 h64;

    if (state->total_len >= 32) {
        U64 const v1 = state->v1;
        U64 const v2 = state->v2;
        U64 const v3 = state->v3;
        U64 const v4 = state->v4;

        h64 = pgo_XXH_rotl64(v1, 1) + pgo_XXH_rotl64(v2, 7) + pgo_XXH_rotl64(v3, 12) + pgo_XXH_rotl64(v4, 18);
        h64 = pgo_XXH64_mergeRound(h64, v1);
        h64 = pgo_XXH64_mergeRound(h64, v2);
        h64 = pgo_XXH64_mergeRound(h64, v3);
        h64 = pgo_XXH64_mergeRound(h64, v4);
    } else {
        h64  = state->seed + PRIME64_5;
    }

    h64 += (U64) state->total_len;

    while (p+8<=bEnd) {
        U64 const k1 = pgo_XXH64_round(0, pgo_XXH_readLE64(p, endian));
        h64 ^= k1;
        h64  = pgo_XXH_rotl64(h64,27) * PRIME64_1 + PRIME64_4;
        p+=8;
    }

    if (p+4<=bEnd) {
        h64 ^= (U64)(pgo_XXH_readLE32(p, endian)) * PRIME64_1;
        h64  = pgo_XXH_rotl64(h64, 23) * PRIME64_2 + PRIME64_3;
        p+=4;
    }

    while (p<bEnd) {
        h64 ^= (*p) * PRIME64_5;
        h64  = pgo_XXH_rotl64(h64, 11) * PRIME64_1;
        p++;
    }

    h64 ^= h64 >> 33;
    h64 *= PRIME64_2;
    h64 ^= h64 >> 29;
    h64 *= PRIME64_3;
    h64 ^= h64 >> 32;

    return h64;
}


pgo_XXH_PUBLIC_API unsigned long long pgo_XXH64_digest (const pgo_XXH64_state_t* state_in)
{
    pgo_XXH_endianess endian_detected = (pgo_XXH_endianess)pgo_XXH_CPU_LITTLE_ENDIAN;

    if ((endian_detected==pgo_XXH_littleEndian) || pgo_XXH_FORCE_NATIVE_FORMAT)
        return pgo_XXH64_digest_endian(state_in, pgo_XXH_littleEndian);
    else
        return pgo_XXH64_digest_endian(state_in, pgo_XXH_bigEndian);
}


/* **************************
*  Canonical representation
****************************/

/*! Default pgo_XXH result types are basic unsigned 32 and 64 bits.
*   The canonical representation follows human-readable write convention, aka big-endian (large digits first).
*   These functions allow transformation of hash result into and from its canonical format.
*   This way, hash values can be written into a file or buffer, and remain comparable across different systems and programs.
*/

pgo_XXH_PUBLIC_API void pgo_XXH32_canonicalFromHash(pgo_XXH32_canonical_t* dst, pgo_XXH32_hash_t hash)
{
    pgo_XXH_STATIC_ASSERT(sizeof(pgo_XXH32_canonical_t) == sizeof(pgo_XXH32_hash_t));
    if (pgo_XXH_CPU_LITTLE_ENDIAN) hash = pgo_XXH_swap32(hash);
    memcpy(dst, &hash, sizeof(*dst));
}

pgo_XXH_PUBLIC_API void pgo_XXH64_canonicalFromHash(pgo_XXH64_canonical_t* dst, pgo_XXH64_hash_t hash)
{
    pgo_XXH_STATIC_ASSERT(sizeof(pgo_XXH64_canonical_t) == sizeof(pgo_XXH64_hash_t));
    if (pgo_XXH_CPU_LITTLE_ENDIAN) hash = pgo_XXH_swap64(hash);
    memcpy(dst, &hash, sizeof(*dst));
}

pgo_XXH_PUBLIC_API pgo_XXH32_hash_t pgo_XXH32_hashFromCanonical(const pgo_XXH32_canonical_t* src)
{
    return pgo_XXH_readBE32(src);
}

pgo_XXH_PUBLIC_API pgo_XXH64_hash_t pgo_XXH64_hashFromCanonical(const pgo_XXH64_canonical_t* src)
{
    return pgo_XXH_readBE64(src);
}
