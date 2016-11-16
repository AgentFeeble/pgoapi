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
    public let url: URL?
    public let statusCode: Int
    public let response: TResponse?
    public let responseHeaders: [String : String]?
}

// All fields are optional, sensible defaults should be provided
public struct RequestArgs
{
    let headers: [String: String]?
    let params: [String: Any]?
    let body: Data?
    
    // All requests with the same session ID will share the same cookies.
    // a value of nil will have cookies shared between all other requests
    // with a nil sessionID
    let sessionId: String?
    
    init(headers: [String : String]? = nil, params: [String : Any]? = nil, body: Data? = nil, sessionId: String? = nil)
    {
        self.headers = headers
        self.params = params
        self.body = body
        self.sessionId = sessionId
    }
}

// Provide an object conforming to this to provide access to the network. Remember to set "Niantic App" as the user agent
public protocol Network
{
    var processingExecutor: Executor { get }
    
    // Clear all cookies for a specific session
    func resetSessionWithID(sessionID: String)
    
    func getJSON(_ endPoint: String, args: RequestArgs?) -> Task<NetworkResponse<Any>>
    func postData(_ endPoint: String, args: RequestArgs?) -> Task<NetworkResponse<Data>>
    func postString(_ endPoint: String, args: RequestArgs?) -> Task<NetworkResponse<String>>
}

public extension Network
{
    static func getUserAgent() -> String
    {
        return "Niantic App"
    }
}
