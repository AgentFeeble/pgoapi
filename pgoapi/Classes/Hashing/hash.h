//
//  hash.h
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/08/08.
//  Copyright © 2016 MC. All rights reserved.
//

#ifndef hash_h
#define hash_h

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif
    
extern uint32_t pgo_hash_32(const void* input, size_t length, uint32_t seed);
extern uint64_t pgo_hash_64(const void* input, size_t length, uint64_t seed);
    
#ifdef __cplusplus
}
#endif

#endif /* hash_h */
