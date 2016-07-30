//
//  CellIDUtility.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/30.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

func getCellIDs(location: Location, radius: Int = 10) -> [UInt64]
{
    let origin = MCS2CellID(forLat: location.latitude, long: location.longitude).parentForLevel(15)
    var left = origin.prev()
    var right = origin.next()
    
    var walk = [origin.cellID]
    for _ in 0 ..< radius
    {
        walk.append(left.cellID)
        walk.append(right.cellID)
        
        left = left.prev()
        right = right.next()
    }
    
    return walk.sort()
}
