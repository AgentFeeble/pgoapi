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

public class AlamoFireNetwork: Network
{
    private let manager: Manager
    private let callbackQueue = dispatch_queue_create("AlamoFire Network Callback Queue", DISPATCH_QUEUE_CONCURRENT)
    
    public var processingExecutor: Executor = {
        let queue = NSOperationQueue()
        queue.name = "AlamoFire Network Process Queue"
        return Executor.OperationQueue(queue)
    }()
    
    public var userAgent: String?
    {
        didSet
        {
            var headers = manager.session.configuration.HTTPAdditionalHeaders ?? [:]
            headers["User-Agent"] = userAgent
            
            manager.session.configuration.HTTPAdditionalHeaders = headers
        }
    }
    
    public class func defaultFireNetwork() -> AlamoFireNetwork
    {
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        let defaultHeaders = Manager.defaultHTTPHeaders
        
        configuration.HTTPAdditionalHeaders = defaultHeaders
        
        let manager = Manager(configuration: configuration)
        manager.delegate.taskWillPerformHTTPRedirection = { session, task, response, request in return nil }
        return AlamoFireNetwork(manager: manager)
    }
    
    public init(manager: Manager)
    {
        self.manager = manager
    }
    
    public func setUserAgent(userAgent: String)
    {
        self.userAgent = userAgent
    }
    
    public func getJSON(endPoint: String) -> Task<NetworkResponse<AnyObject>>
    {
        let responseMethod = ResponseMethod { $0.responseJSON(queue: $1, completionHandler: $2) }
        return self.request(.GET, endPoint: endPoint, params: nil, responseMethod: responseMethod)
    }
    
    public func postData(endPoint: String, params: [String: AnyObject]?) -> Task<NetworkResponse<NSData>>
    {
        let responseMethod = ResponseMethod { $0.responseData(queue: $1, completionHandler: $2) }
        return self.request(.POST, endPoint: endPoint, params: params, responseMethod: responseMethod)
    }
    
    public func postString(endPoint: String, params: [String: AnyObject]?) -> Task<NetworkResponse<String>>
    {
        let responseMethod = ResponseMethod { $0.responseString(queue: $1, completionHandler: $2) }
        return self.request(.POST, endPoint: endPoint, params: params, responseMethod: responseMethod)
    }
    
    private func request<T>(method: Alamofire.Method,
                            endPoint: String,
                            params: [String: AnyObject]?,
                            responseMethod: ResponseMethod<T>) -> Task<NetworkResponse<T>>
    {
        let taskSource = TaskCompletionSource<NetworkResponse<T>>()
        
        let request = manager.request(method, endPoint, parameters: params)
        responseMethod.invocation(request: request, queue: callbackQueue)
        {
            (response: Response<T, NSError>) in
            
            switch response.result
            {
            case .Success(let value):
                taskSource.setResult(NetworkResponse(response: value, responseHeaders: response.response?.allHeaderFields))
            case .Failure(let error):
                taskSource.setError(error)
            }
        }
        
        return taskSource.task
    }
}

private struct ResponseMethod<TResponse>
{
    let invocation: (request: Request, queue: dispatch_queue_t?, completionHandler: Response<TResponse, NSError> -> Void) -> ()
}
