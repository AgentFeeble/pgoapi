/*
   pgo_xxHash - Extremely Fast Hash algorithm
   Header File
   Copyright (C) 2012-2016, Yann Collet.

   BSD 2-Clause License (http://www.opensource.org/licenses/bsd-license.php)

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions are
   met:

       * Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
       * Redistributions in binary form must reproduce the above
   copyright notice, this list of conditions and the following disclaimer
   in the documentation and/or other materials provided with the
   distribution.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

   You can contact the author at :
   - pgo_xxHash source repository : https://github.com/Cyan4973/xxHash
*/

/* Notice extracted from pgo_xxHash homepage :

pgo_xxHash is an extremely fast Hash algorithm, running at RAM speed limits.
It also successfully passes all tests from the SMHasher suite.

Comparison (single thread, Windows Seven 32 bits, using SMHasher on a Core 2 Duo @3GHz)

Name            Speed       Q.Score   Author
pgo_xxHash          5.4 GB/s     10
CrapWow         3.2 GB/s      2       Andrew
MumurHash 3a    2.7 GB/s     10       Austin Appleby
SpookyHash      2.0 GB/s     10       Bob Jenkins
SBox            1.4 GB/s      9       Bret Mulvey
Lookup3         1.2 GB/s      9       Bob Jenkins
SuperFastHash   1.2 GB/s      1       Paul Hsieh
CityHash64      1.05 GB/s    10       Pike & Alakuijala
FNV             0.55 GB/s     5       Fowler, Noll, Vo
CRC32           0.43 GB/s     9
MD5-32          0.33 GB/s    10       Ronald L. Rivest
SHA1-32         0.28 GB/s    10

Q.Score is a measure of quality of the hash function.
It depends on successfully passing SMHasher test set.
10 is a perfect score.

A 64-bits version, named pgo_XXH64, is available since r35.
It offers much better speed, but for 64-bits applications only.
Name     Speed on 64 bits    Speed on 32 bits
pgo_XXH64       13.8 GB/s            1.9 GB/s
pgo_XXH32        6.8 GB/s            6.0 GB/s
*/

#ifndef pgo_XXHASH_H_5627135585666179
#define pgo_XXHASH_H_5627135585666179 1

#if defined (__cplusplus)
extern "C" {
#endif


/* ****************************
*  Definitions
******************************/
#include <stddef.h>   /* size_t */
typedef enum { pgo_XXH_OK=0, pgo_XXH_ERROR } pgo_XXH_errorcode;


/* ****************************
*  API modifier
******************************/
/** pgo_XXH_PRIVATE_API
*   This is useful if you want to include pgo_xxhash functions in `static` mode
*   in order to inline them, and remove their symbol from the public list.
*   Methodology :
*     #define pgo_XXH_PRIVATE_API
*     #include "pgo_xxhash.h"
*   `pgo_xxhash.c` is automatically included, so the file is still needed,
*   but it's not useful to compile and link it anymore.
*/
#ifdef pgo_XXH_PRIVATE_API
#  ifndef pgo_XXH_STATIC_LINKING_ONLY
#    define pgo_XXH_STATIC_LINKING_ONLY
#  endif
#  if defined(__GNUC__)
#    define pgo_XXH_PUBLIC_API static __attribute__((unused))
#  elif defined (__cplusplus) || (defined (__STDC_VERSION__) && (__STDC_VERSION__ >= 199901L) /* C99 */)
#    define pgo_XXH_PUBLIC_API static inline
#  elif defined(_MSC_VER)
#    define pgo_XXH_PUBLIC_API static __inline
#  else
#    define pgo_XXH_PUBLIC_API static   /* this version may generate warnings for unused static functions; disable the relevant warning */
#  endif
#else
#  define pgo_XXH_PUBLIC_API   /* do nothing */
#endif /* pgo_XXH_PRIVATE_API */

/*!pgo_XXH_NAMESPACE, aka Namespace Emulation :

If you want to include _and expose_ pgo_xxHash functions from within your own library,
but also want to avoid symbol collisions with another library which also includes pgo_xxHash,

you can use pgo_XXH_NAMESPACE, to automatically prefix any public symbol from pgo_xxhash library
with the value of pgo_XXH_NAMESPACE (so avoid to keep it NULL and avoid numeric values).

Note that no change is required within the calling program as long as it includes `pgo_xxhash.h` :
regular symbol name will be automatically translated by this header.
*/
#ifdef pgo_XXH_NAMESPACE
#  define pgo_XXH_CAT(A,B) A##B
#  define pgo_XXH_NAME2(A,B) pgo_XXH_CAT(A,B)
#  define pgo_XXH32 pgo_XXH_NAME2(pgo_XXH_NAMESPACE, pgo_XXH32)
#  define pgo_XXH64 pgo_XXH_NAME2(pgo_XXH_NAMESPACE, pgo_XXH64)
#  define pgo_XXH_versionNumber pgo_XXH_NAME2(pgo_XXH_NAMESPACE, pgo_XXH_versionNumber)
#  define pgo_XXH32_createState pgo_XXH_NAME2(pgo_XXH_NAMESPACE, pgo_XXH32_createState)
#  define pgo_XXH64_createState pgo_XXH_NAME2(pgo_XXH_NAMESPACE, pgo_XXH64_createState)
#  define pgo_XXH32_freeState pgo_XXH_NAME2(pgo_XXH_NAMESPACE, pgo_XXH32_freeState)
#  define pgo_XXH64_freeState pgo_XXH_NAME2(pgo_XXH_NAMESPACE, pgo_XXH64_freeState)
#  define pgo_XXH32_reset pgo_XXH_NAME2(pgo_XXH_NAMESPACE, pgo_XXH32_reset)
#  define pgo_XXH64_reset pgo_XXH_NAME2(pgo_XXH_NAMESPACE, pgo_XXH64_reset)
#  define pgo_XXH32_update pgo_XXH_NAME2(pgo_XXH_NAMESPACE, pgo_XXH32_update)
#  define pgo_XXH64_update pgo_XXH_NAME2(pgo_XXH_NAMESPACE, pgo_XXH64_update)
#  define pgo_XXH32_digest pgo_XXH_NAME2(pgo_XXH_NAMESPACE, pgo_XXH32_digest)
#  define pgo_XXH64_digest pgo_XXH_NAME2(pgo_XXH_NAMESPACE, pgo_XXH64_digest)
#  define pgo_XXH32_copyState pgo_XXH_NAME2(pgo_XXH_NAMESPACE, pgo_XXH32_copyState)
#  define pgo_XXH64_copyState pgo_XXH_NAME2(pgo_XXH_NAMESPACE, pgo_XXH64_copyState)
#endif


/* *************************************
*  Version
***************************************/
#define pgo_XXH_VERSION_MAJOR    0
#define pgo_XXH_VERSION_MINOR    6
#define pgo_XXH_VERSION_RELEASE  1
#define pgo_XXH_VERSION_NUMBER  (pgo_XXH_VERSION_MAJOR *100*100 + pgo_XXH_VERSION_MINOR *100 + pgo_XXH_VERSION_RELEASE)
pgo_XXH_PUBLIC_API unsigned pgo_XXH_versionNumber (void);


/* ****************************
*  Simple Hash Functions
******************************/
typedef unsigned int       pgo_XXH32_hash_t;
typedef unsigned long long pgo_XXH64_hash_t;

pgo_XXH_PUBLIC_API pgo_XXH32_hash_t pgo_XXH32 (const void* input, size_t length, unsigned int seed);
pgo_XXH_PUBLIC_API pgo_XXH64_hash_t pgo_XXH64 (const void* input, size_t length, unsigned long long seed);

/*!
pgo_XXH32() :
    Calculate the 32-bits hash of sequence "length" bytes stored at memory address "input".
    The memory between input & input+length must be valid (allocated and read-accessible).
    "seed" can be used to alter the result predictably.
    Speed on Core 2 Duo @ 3 GHz (single thread, SMHasher benchmark) : 5.4 GB/s
pgo_XXH64() :
    Calculate the 64-bits hash of sequence of length "len" stored at memory address "input".
    "seed" can be used to alter the result predictably.
    This function runs 2x faster on 64-bits systems, but slower on 32-bits systems (see benchmark).
*/


/* ****************************
*  Streaming Hash Functions
******************************/
typedef struct pgo_XXH32_state_s pgo_XXH32_state_t;   /* incomplete type */
typedef struct pgo_XXH64_state_s pgo_XXH64_state_t;   /* incomplete type */

/*! State allocation, compatible with dynamic libraries */

pgo_XXH_PUBLIC_API pgo_XXH32_state_t* pgo_XXH32_createState(void);
pgo_XXH_PUBLIC_API pgo_XXH_errorcode  pgo_XXH32_freeState(pgo_XXH32_state_t* statePtr);

pgo_XXH_PUBLIC_API pgo_XXH64_state_t* pgo_XXH64_createState(void);
pgo_XXH_PUBLIC_API pgo_XXH_errorcode  pgo_XXH64_freeState(pgo_XXH64_state_t* statePtr);


/* hash streaming */

pgo_XXH_PUBLIC_API pgo_XXH_errorcode pgo_XXH32_reset  (pgo_XXH32_state_t* statePtr, unsigned int seed);
pgo_XXH_PUBLIC_API pgo_XXH_errorcode pgo_XXH32_update (pgo_XXH32_state_t* statePtr, const void* input, size_t length);
pgo_XXH_PUBLIC_API pgo_XXH32_hash_t  pgo_XXH32_digest (const pgo_XXH32_state_t* statePtr);

pgo_XXH_PUBLIC_API pgo_XXH_errorcode pgo_XXH64_reset  (pgo_XXH64_state_t* statePtr, unsigned long long seed);
pgo_XXH_PUBLIC_API pgo_XXH_errorcode pgo_XXH64_update (pgo_XXH64_state_t* statePtr, const void* input, size_t length);
pgo_XXH_PUBLIC_API pgo_XXH64_hash_t  pgo_XXH64_digest (const pgo_XXH64_state_t* statePtr);

/*
These functions generate the pgo_xxHash of an input provided in multiple segments.
Note that, for small input, they are slower than single-call functions, due to state management.
For small input, prefer `pgo_XXH32()` and `pgo_XXH64()` .

pgo_XXH state must first be allocated, using pgo_XXH*_createState() .

Start a new hash by initializing state with a seed, using pgo_XXH*_reset().

Then, feed the hash state by calling pgo_XXH*_update() as many times as necessary.
Obviously, input must be allocated and read accessible.
The function returns an error code, with 0 meaning OK, and any other value meaning there is an error.

Finally, a hash value can be produced anytime, by using pgo_XXH*_digest().
This function returns the nn-bits hash as an int or long long.

It's still possible to continue inserting input into the hash state after a digest,
and generate some new hashes later on, by calling again pgo_XXH*_digest().

When done, free pgo_XXH state space if it was allocated dynamically.
*/


/* **************************
*  Utils
****************************/
#if !(defined(__STDC_VERSION__) && (__STDC_VERSION__ >= 199901L))   /* ! C99 */
#  define restrict   /* disable restrict */
#endif

pgo_XXH_PUBLIC_API void pgo_XXH32_copyState(pgo_XXH32_state_t* restrict dst_state, const pgo_XXH32_state_t* restrict src_state);
pgo_XXH_PUBLIC_API void pgo_XXH64_copyState(pgo_XXH64_state_t* restrict dst_state, const pgo_XXH64_state_t* restrict src_state);


/* **************************
*  Canonical representation
****************************/
typedef struct { unsigned char digest[4]; } pgo_XXH32_canonical_t;
typedef struct { unsigned char digest[8]; } pgo_XXH64_canonical_t;

pgo_XXH_PUBLIC_API void pgo_XXH32_canonicalFromHash(pgo_XXH32_canonical_t* dst, pgo_XXH32_hash_t hash);
pgo_XXH_PUBLIC_API void pgo_XXH64_canonicalFromHash(pgo_XXH64_canonical_t* dst, pgo_XXH64_hash_t hash);

pgo_XXH_PUBLIC_API pgo_XXH32_hash_t pgo_XXH32_hashFromCanonical(const pgo_XXH32_canonical_t* src);
pgo_XXH_PUBLIC_API pgo_XXH64_hash_t pgo_XXH64_hashFromCanonical(const pgo_XXH64_canonical_t* src);

/* Default result type for pgo_XXH functions are primitive unsigned 32 and 64 bits.
*  The canonical representation uses human-readable write convention, aka big-endian (large digits first).
*  These functions allow transformation of hash result into and from its canonical format.
*  This way, hash values can be written into a file / memory, and remain comparable on different systems and programs.
*/


#ifdef pgo_XXH_STATIC_LINKING_ONLY

/* ================================================================================================
   This section contains definitions which are not guaranteed to remain stable.
   They could change in a future version, becoming incompatible with a different version of the library.
   They shall only be used with static linking.
=================================================================================================== */

/* These definitions allow allocating pgo_XXH state statically (on stack) */

   struct pgo_XXH32_state_s {
       unsigned long long total_len;
       unsigned seed;
       unsigned v1;
       unsigned v2;
       unsigned v3;
       unsigned v4;
       unsigned mem32[4];   /* buffer defined as U32 for alignment */
       unsigned memsize;
   };   /* typedef'd to pgo_XXH32_state_t */

   struct pgo_XXH64_state_s {
       unsigned long long total_len;
       unsigned long long seed;
       unsigned long long v1;
       unsigned long long v2;
       unsigned long long v3;
       unsigned long long v4;
       unsigned long long mem64[4];   /* buffer defined as U64 for alignment */
       unsigned memsize;
   };   /* typedef'd to pgo_XXH64_state_t */


#  ifdef pgo_XXH_PRIVATE_API
#    include "pgo_xxhash.c"   /* include pgo_xxhash functions as `static`, for inlining */
#  endif

#endif /* pgo_XXH_STATIC_LINKING_ONLY */


#if defined (__cplusplus)
}
#endif

#endif /* pgo_XXHASH_H_5627135585666179 */
