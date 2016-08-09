//
//  Location.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/28.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

public struct Location
{
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double
    
    public init(latitude: Double, longitude: Double, altitude: Double = 0.0)
    {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
    }    
}
