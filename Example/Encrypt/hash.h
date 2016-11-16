//
//  hash.h
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/11/16.
//  Copyright © 2016 MC. All rights reserved.
//

#ifndef hash_h
#define hash_h

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif
    
uint64_t compute_hash(const uint8_t *in, uint32_t len);
    
#ifdef __cplusplus
}
#endif

#endif /* hash_h */
