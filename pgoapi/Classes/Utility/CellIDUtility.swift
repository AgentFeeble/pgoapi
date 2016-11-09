//
//  CellIDUtility.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/30.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

func getCellIDs(_ location: Location, radius: Int = 1000) -> [UInt64]
{
    // Max values allowed by server according to this comment:
    // https://github.com/AeonLucid/POGOProtos/issues/83#issuecomment-235612285
    let r = min(radius, 1500)
    let level = Int32(15)
    let maxCells = Int32(100) //100 is max allowed by the server
    
    let cells = MCS2CellID.cellIDsForRegion(atLat: location.latitude,
                                                 long: location.longitude,
                                                 radius: Double(r),
                                                 level: level,
                                                 maxCellCount: maxCells)
    
    return cells.map({ $0.cellID }).sorted()
}
