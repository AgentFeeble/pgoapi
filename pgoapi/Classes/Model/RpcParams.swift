//
//  RpcParams.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/28.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

struct RpcParams
{
    let authToken: AuthToken
    let requestId: UInt64
    let sessionStartTime: UInt64
    let authTicket: AuthTicket?
    let location: Location?
}
