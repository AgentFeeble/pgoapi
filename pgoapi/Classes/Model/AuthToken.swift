//
//  AuthToken.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/25.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

public class AuthToken
{
    public let token: String
    public let expiry: NSDate
    
    public init(token: String, expiry: NSDate)
    {
        self.token = token
        self.expiry = expiry
    }
}

extension AuthToken: CustomStringConvertible
{
    public var description: String
    {
        return "\(String(self.dynamicType)): token=\(token); expiry=\(expiry)"
    }
}

public extension AuthToken
{
    public func isExpired() -> Bool
    {
        return NSDate().compare(expiry) != .OrderedDescending
    }
}
