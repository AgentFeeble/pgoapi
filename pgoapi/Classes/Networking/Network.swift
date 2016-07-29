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
    public let statusCode: Int
    public let response: TResponse?
    public let responseHeaders: [NSObject : AnyObject]?
}

// Provide an object conforming to this to provide access to the network. Remember to set "niantic" as the user agent
public protocol Network
{
    var processingExecutor: Executor { get }
    
    func getJSON(endPoint: String) -> Task<NetworkResponse<AnyObject>>
    func postData(endPoint: String, params: [String: AnyObject]?, body: NSData?) -> Task<NetworkResponse<NSData>>
    func postString(endPoint: String, params: [String: AnyObject]?, body: NSData?) -> Task<NetworkResponse<String>>
}

public extension Network
{
    static func getUserAgent() -> String
    {
        return "niantic"
    }
}

// Workaround for using default args in a protocol
public extension Network
{
    func postData(endPoint: String) -> Task<NetworkResponse<NSData>>
    {
        return postData(endPoint, params: nil, body: nil)
    }
    
    func postData(endPoint: String, params: [String: AnyObject]?) -> Task<NetworkResponse<NSData>>
    {
        return postData(endPoint, params: params, body: nil)
    }
    
    func postString(endPoint: String) -> Task<NetworkResponse<String>>
    {
        return postString(endPoint, params: nil, body: nil)
    }
    
    func postString(endPoint: String, params: [String: AnyObject]?) -> Task<NetworkResponse<String>>
    {
        return postString(endPoint, params: params, body: nil)
    }
}


