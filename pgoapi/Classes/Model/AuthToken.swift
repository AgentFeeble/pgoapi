//
//  AuthToken.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/25.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

public struct AuthToken
{
    let token: String
    let expiry: Date
    
    public init(token: String, expiry: Date)
    {
        self.token = token
        self.expiry = expiry
    }
}

extension AuthToken: CustomStringConvertible
{
    public var description: String
    {
        return "\(String(describing: type(of: self))): token=\(token); expiry=\(expiry)"
    }
}

public extension AuthToken
{
    public func isExpired() -> Bool
    {
        return Date().compare(expiry) != .orderedDescending
    }
}
