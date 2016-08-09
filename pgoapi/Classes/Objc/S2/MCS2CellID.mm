//
//  MCS2CellID.m
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/30.
//  Copyright © 2016 MC. All rights reserved.
//

// The S2 library uses deprecated data types. This silences these warnings.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-W#warnings"

#include <s2.h>
#include <s2cellid.h>
#include <s2latlng.h>
#include <s2cap.h>
#include <s2regioncoverer.h>

#pragma clang diagnostic pop

#import "MCS2CellID.h"

#define EARTH_RADIUS 6371.0 * 1000.0

@interface MCS2CellID ()

@property (nonatomic, assign) S2CellId cellId;

+ (instancetype)cellIDWithWithCellId:(S2CellId)cellId;
- (instancetype)initWithCellId:(S2CellId)cellId;

@end

@implementation MCS2CellID

+ (instancetype)cellIDForLat:(double)latitude long:(double)longitude
{
    S2LatLng coord = S2LatLng::FromDegrees(latitude, longitude);
    S2CellId cellId = S2CellId::FromLatLng(coord);
    return [[self alloc] initWithCellId:cellId];
}

+ (instancetype)cellIDWithWithCellId:(S2CellId)cellId
{
    return [[self alloc] initWithCellId:cellId];
}

- (instancetype)initWithCellId:(S2CellId)cellId
{
    if (self = [super init])
    {
        _cellId = cellId;
    }
    return self;
}

+ (NSArray<MCS2CellID *> *)cellIDsForRegionAtLat:(double)latitude
                                            long:(double)longitude
                                          radius:(double)radius
                                           level:(int)level
                                    maxCellCount:(int)maxCells
{
    S2Point axis = S2LatLng::FromDegrees(latitude, longitude).ToPoint();
    S1Angle angle = S1Angle::Degrees(360*radius/(2.0 * M_PI * EARTH_RADIUS));
    S2Cap cap = S2Cap::FromAxisAngle(axis, angle);
    S2RegionCoverer coverer;
    std::vector<S2CellId> cells;
    
    coverer.set_min_level(level);
    coverer.set_max_level(level);
    coverer.set_max_cells(maxCells);
    
    coverer.GetCovering(cap, &cells);
    
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:cells.size()];
    for (auto const& value: cells)
    {
        [result addObject:[self cellIDWithWithCellId:value]];
    }
    
    return result;
}

- (instancetype)parent
{
    return [[self class] cellIDWithWithCellId:self.cellId.parent()];
}

- (instancetype)parentForLevel:(int)level
{
    return [[self class] cellIDWithWithCellId:self.cellId.parent(level)];
}

- (instancetype)next
{
    return [[self class] cellIDWithWithCellId:self.cellId.next()];
}

- (instancetype)prev
{
    return [[self class] cellIDWithWithCellId:self.cellId.prev()];
}

- (uint64_t)cellID
{
    return self.cellId.id();
}

@end
