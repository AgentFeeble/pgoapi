//
//  RequestMessage.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/27.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation
import ProtocolBuffers

struct RequestMessage
{
    let type: Pogoprotos.Networking.Requests.RequestType
    let message: GeneratedMessage
}
