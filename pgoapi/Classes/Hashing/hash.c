//
//  hash.c
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/08/08.
//  Copyright © 2016 MC. All rights reserved.
//

#include "hash.h"
#include "pgo_xxhash.h"

extern uint32_t pgo_hash_32(const void* input, size_t length, uint32_t seed)
{
    return pgo_XXH32(input, length, seed);
}

extern uint64_t pgo_hash_64(const void* input, size_t length, uint64_t seed)
{
    return pgo_XXH64(input, length, seed);
}
