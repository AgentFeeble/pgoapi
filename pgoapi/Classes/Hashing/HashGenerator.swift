//
//  HashGenerator.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2017/01/01.
//  Copyright © 2017 MC. All rights reserved.
//

import BoltsSwift
import Foundation

public struct HashResult
{
    let locationAuthHash: Int32
    let locationHash: Int32
    let requestHashes: [UInt64]
}

public protocol HashGenerator
{
    var unknown25: UInt64 { get }
    func generateHash(timestamp: UInt64,
                      latitude: Double,
                      longitude: Double,
                      altitude: Double,
                      authTicket: Data,
                      sessionData: Data,
                      requests: [Data]) -> Task<HashResult>
}
