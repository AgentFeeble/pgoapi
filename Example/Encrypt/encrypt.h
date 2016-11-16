//
//  encrypt.h
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/08/07.
//  Copyright © 2016 MC. All rights reserved.
//

#ifndef encrypt_h
#define encrypt_h

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

extern int encryptMethod(const char* input, size_t len, uint32_t ms, char** output);
extern int decryptMethod(const char* input, size_t len, char** output);
    
#ifdef __cplusplus
}
#endif

#endif /* encrypt_h */
