//
//  AuthTicket.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/08/08.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

struct AuthTicket
{
    let expireTimestamp_ms: UInt64
    let start: NSData
    let end: NSData
}
