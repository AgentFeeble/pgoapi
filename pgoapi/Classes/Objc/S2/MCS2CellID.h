//
//  MCS2CellID.h
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/30.
//  Copyright © 2016 MC. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Objective C wrapper over the S2 library
 */
@interface MCS2CellID : NSObject

@property (nonatomic, readonly) uint64_t cellID;

+ (instancetype)cellIDForLat:(double)latitude long:(double)longitude;

- (instancetype)parent;
- (instancetype)parentForLevel:(int)level;
- (instancetype)next;
- (instancetype)prev;

@end
