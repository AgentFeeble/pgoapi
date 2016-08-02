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
        self.manager = manager
    }
    
    public func getJSON(endPoint: String) -> Task<NetworkResponse<AnyObject>>
    {
        let responseMethod = ResponseMethod { $0.responseJSON(queue: $1, completionHandler: $2) }
        return self.request(.GET, endPoint: endPoint, params: nil, body: nil, responseMethod: responseMethod)
    }
    
    public func postData(endPoint: String, params: [String: AnyObject]?, body: NSData?) -> Task<NetworkResponse<NSData>>
    {
        let responseMethod = ResponseMethod { $0.responseData(queue: $1, completionHandler: $2) }
        return self.request(.POST, endPoint: endPoint, params: params, body: body, responseMethod: responseMethod)
    }
    
    public func postString(endPoint: String, params: [String: AnyObject]?, body: NSData?) -> Task<NetworkResponse<String>>
    {
        let responseMethod = ResponseMethod { $0.responseString(queue: $1, completionHandler: $2) }
        return self.request(.POST, endPoint: endPoint, params: params, body: body, responseMethod: responseMethod)
    }
    
    private func request<T>(method: Alamofire.Method,
                            endPoint: String,
                            params: [String: AnyObject]?,
                            body: NSData?,
                            responseMethod: ResponseMethod<T>) -> Task<NetworkResponse<T>>
    {
        let taskSource = TaskCompletionSource<NetworkResponse<T>>()
        let encoding = body == nil ? ParameterEncoding.URL : ParameterEncoding.Custom(
        {
            (convertible: URLRequestConvertible, params: [String : AnyObject]?) -> (NSMutableURLRequest, NSError?) in
            let mutableRequest = convertible.URLRequest.copy() as! NSMutableURLRequest
            mutableRequest.HTTPBody = body
            return (mutableRequest, nil)
        })
        
        let request = manager.request(method, endPoint, parameters: params, encoding: encoding)
        responseMethod.invocation(request: request, queue: callbackQueue)
        {
            (response: Response<T, NSError>) in
            
            switch response.result
            {
            case .Success(let value):
                taskSource.set(result: NetworkResponse(statusCode: response.response?.statusCode ?? 0,
                                                       response: value,
                                                       responseHeaders: response.response?.allHeaderFields))
            case .Failure(let error):
                taskSource.set(error: error)
            }
        }
        
        return taskSource.task
    }
}

private struct ResponseMethod<TResponse>
{
    let invocation: (request: Request, queue: dispatch_queue_t?, completionHandler: Response<TResponse, NSError> -> Void) -> ()
}
