//
//  Network.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/25.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation
import BoltsSwift

public struct NetworkResponse<TResponse>
{
    public let response: TResponse?
    public let responseHeaders: [NSObject : AnyObject]?
}

public protocol Network
{
    var processingExecutor: Executor { get }
    
    func setUserAgent(userAgent: String)
    
    func getJSON(endPoint: String) -> Task<NetworkResponse<AnyObject>>
    func postData(endPoint: String, params: [String: AnyObject]?) -> Task<NetworkResponse<NSData>>
    func postString(endPoint: String, params: [String: AnyObject]?) -> Task<NetworkResponse<String>>
}

// Workaround for using default args in a protocol
public extension Network
{
    func postData(endPoint: String) -> Task<NetworkResponse<NSData>>
    {
        return postData(endPoint, params: nil)
    }
    
    func postString(endPoint: String) -> Task<NetworkResponse<String>>
    {
        return postString(endPoint, params: nil)
    }
}


