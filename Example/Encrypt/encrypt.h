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

extern int encryptMethod(const unsigned char *input,
                         size_t input_size,
                         const unsigned char* iv,
                         size_t iv_size,
                         unsigned char* output,
                         size_t * output_size);
    
#ifdef __cplusplus
}
#endif

#endif /* encrypt_h */
