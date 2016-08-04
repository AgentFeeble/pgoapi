//
//  AlamoFireNetwork.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/27.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation
import Alamofire
import BoltsSwift

public class AlamoFireNetwork: Network, Synchronizable
{
    private let defaultManager: Manager
    private var isolatedManagerMap: [String: Manager] = [:] // maps sessionID to manager
    private let callbackQueue = dispatch_queue_create("AlamoFire Network Callback Queue", DISPATCH_QUEUE_CONCURRENT)
    
    let synchronizationLock: dispatch_queue_t = dispatch_queue_create("AlamoFireNetwork Synchronization", nil)
    
    public var processingExecutor: Executor = {
        let queue = NSOperationQueue()
        queue.name = "AlamoFire Network Process Queue"
        return Executor.OperationQueue(queue)
    }()
    
    public class func defaultFireNetwork() -> AlamoFireNetwork
    {
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        var headers = Manager.defaultHTTPHeaders
        
        headers["User-Agent"] = getUserAgent()
        configuration.HTTPAdditionalHeaders = headers
        
        let manager = Manager(configuration: configuration)
        manager.delegate.taskWillPerformHTTPRedirection = { session, task, response, request in return nil }
        return AlamoFireNetwork(manager: manager)
    }
    
    public init(manager: Manager)
    {
        self.defaultManager = manager
    }
    
    public func resetSessionWithID(sessionID sessionID: String)
    {
        sync{ self.isolatedManagerMap.removeValueForKey(sessionID) }
    }
    
    public func getJSON(endPoint: String, args: RequestArgs?) -> Task<NetworkResponse<AnyObject>>
    {
        let responseMethod = ResponseMethod { $0.responseJSON(queue: $1, completionHandler: $2) }
        return self.request(.GET, endPoint: endPoint, args: args, responseMethod: responseMethod)
    }
    
    public func postData(endPoint: String,  args: RequestArgs?) -> Task<NetworkResponse<NSData>>
    {
        let responseMethod = ResponseMethod { $0.responseData(queue: $1, completionHandler: $2) }
        return self.request(.POST, endPoint: endPoint, args: args, responseMethod: responseMethod)
    }
    
    public func postString(endPoint: String,  args: RequestArgs?) -> Task<NetworkResponse<String>>
    {
        let responseMethod = ResponseMethod { $0.responseString(queue: $1, completionHandler: $2) }
        return self.request(.POST, endPoint: endPoint, args: args, responseMethod: responseMethod)
    }
    
    private func request<T>(method: Alamofire.Method,
                            endPoint: String,
                            args: RequestArgs?,
                            responseMethod: ResponseMethod<T>) -> Task<NetworkResponse<T>>
    {
        let manager = managerFor(args)
        
        let taskSource = TaskCompletionSource<NetworkResponse<T>>()
        let encoding = args?.body == nil ? ParameterEncoding.URL : ParameterEncoding.Custom(
        {
            (convertible: URLRequestConvertible, params: [String : AnyObject]?) -> (NSMutableURLRequest, NSError?) in
            let mutableRequest = convertible.URLRequest.copy() as! NSMutableURLRequest
            mutableRequest.HTTPBody = args?.body
            return (mutableRequest, nil)
        })
        
        let request = manager.request(method, endPoint, parameters: args?.params, encoding: encoding)
        responseMethod.invocation(request: request, queue: callbackQueue)
        {
            (response: Response<T, NSError>) in
            
            switch response.result
            {
            case .Success(let value):
                taskSource.set(result: NetworkResponse(url: response.response?.URL,
                                                       statusCode: response.response?.statusCode ?? 0,
                                                       response: value,
                                                       responseHeaders: response.response?.allHeaderFields as? [String: String]))
            case .Failure(let error):
                taskSource.set(error: error)
            }
        }
        
        return taskSource.task
    }
    
    private func managerFor(args: RequestArgs?) -> Manager
    {
        guard let sessionId = args?.sessionId else
        {
            return defaultManager
        }
        
        return sync
        {
            if let manager = self.isolatedManagerMap[sessionId]
            {
                return manager
            }
            
            let sessionConfig = self.defaultManager.session.configuration.copy() as! NSURLSessionConfiguration
            sessionConfig.HTTPCookieStorage = MemoryCookieStorage()
            
            let manager = Manager(configuration: sessionConfig)
            manager.delegate.taskWillPerformHTTPRedirection = { session, task, response, request in return nil }
            
            self.isolatedManagerMap[sessionId] = manager
            
            return manager
        }
    }
}

private struct ResponseMethod<TResponse>
{
    let invocation: (request: Request, queue: dispatch_queue_t?, completionHandler: Response<TResponse, NSError> -> Void) -> ()
}
