//
//  ApiResponse.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/28.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation
import ProtocolBuffers

public struct ApiResponse
{
    public typealias RequestType = Pogoprotos.Networking.Requests.RequestType
    
    public let response: Pogoprotos.Networking.Envelopes.ResponseEnvelope
    public let subresponses: [RequestType : GeneratedMessage]
}
