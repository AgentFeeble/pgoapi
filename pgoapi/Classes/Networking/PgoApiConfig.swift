//
//  PgoApiConfig.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2017/01/01.
//  Copyright © 2017 MC. All rights reserved.
//

import Foundation

public struct PgoApiConfig
{
    public let network: Network
    public let hasher: HashGenerator
    
    public init(network: Network, hasher: HashGenerator)
    {
        self.network = network
        self.hasher = hasher
    }
}
