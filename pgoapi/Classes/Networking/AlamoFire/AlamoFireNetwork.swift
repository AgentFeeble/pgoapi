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

open class AlamoFireNetwork: Network, Synchronizable
{
    private let defaultManager: SessionManager
    private var isolatedManagerMap: [String: SessionManager] = [:] // maps sessionID to manager
    private let callbackQueue = DispatchQueue(label: "AlamoFire Network Callback Queue", attributes: DispatchQueue.Attributes.concurrent)
    
    let synchronizationLock: DispatchQueue = DispatchQueue(label: "AlamoFireNetwork Synchronization", attributes: [])
    
    open var processingExecutor: Executor = {
        let queue = OperationQueue()
        queue.name = "AlamoFire Network Process Queue"
        return Executor.operationQueue(queue)
    }()
    
    open class func defaultFireNetwork() -> AlamoFireNetwork
    {
        let configuration = URLSessionConfiguration.default
        var headers = SessionManager.defaultHTTPHeaders
        
        headers["User-Agent"] = getUserAgent()
        configuration.httpAdditionalHeaders = headers
        
        let manager = SessionManager(configuration: configuration)
        manager.delegate.taskWillPerformHTTPRedirection = { session, task, response, request in return nil }
        return AlamoFireNetwork(manager: manager)
    }
    
    public init(manager: SessionManager)
    {
        self.defaultManager = manager
    }
    
    open func resetSessionWithID(sessionID: String)
    {
        sync{ self.isolatedManagerMap.removeValue(forKey: sessionID) }
    }
    
    open func getJSON(_ endPoint: String, args: RequestArgs?) -> Task<NetworkResponse<Any>>
    {
        let responseMethod = ResponseMethod { (request, queue, handler) in request.responseJSON(queue: queue, completionHandler: handler) }
        return self.request(.get, endPoint: endPoint, args: args, responseMethod: responseMethod)
    }
    
    open func postData(_ endPoint: String,  args: RequestArgs?) -> Task<NetworkResponse<Data>>
    {
        let responseMethod = ResponseMethod { (request, queue, handler) in request.responseData(queue: queue, completionHandler: handler) }
        return self.request(.post, endPoint: endPoint, args: args, responseMethod: responseMethod)
    }
    
    open func postString(_ endPoint: String,  args: RequestArgs?) -> Task<NetworkResponse<String>>
    {
        let responseMethod = ResponseMethod { (request, queue, handler) in request.responseString(queue: queue, completionHandler: handler) }
        return self.request(.post, endPoint: endPoint, args: args, responseMethod: responseMethod)
    }
    
    private func request<T>(_ method: HTTPMethod,
                            endPoint: String,
                            args: RequestArgs?,
                            responseMethod: ResponseMethod<T>) -> Task<NetworkResponse<T>>
    {
        let manager = managerFor(args)
        
        let taskSource = TaskCompletionSource<NetworkResponse<T>>()
        let encoding = encodingFor(args: args)
        
        let request = manager.request(endPoint, method: method, parameters: args?.params, encoding: encoding)
        responseMethod.invocation(request, callbackQueue)
        {
            (response: DataResponse<T>) in
            
            switch response.result
            {
            case .success(let value):
                taskSource.set(result: NetworkResponse(url: response.response?.url,
                                                       statusCode: response.response?.statusCode ?? 0,
                                                       response: value,
                                                       responseHeaders: response.response?.allHeaderFields as? [String: String]))
            case .failure(let error):
                taskSource.set(error: error)
            }
        }
        
        return taskSource.task
    }
    
    private func encodingFor(args: RequestArgs?) -> ParameterEncoding
    {
        if let body = args?.body
        {
            return DataBodyParameterEncoding(body: body)
        }
        return URLEncoding(destination: .methodDependent)
    }
    
    private func managerFor(_ args: RequestArgs?) -> SessionManager
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
            
            let sessionConfig = self.defaultManager.session.configuration.copy() as! URLSessionConfiguration
            sessionConfig.httpCookieStorage = MemoryCookieStorage()
            
            let manager = SessionManager(configuration: sessionConfig)
            manager.delegate.taskWillPerformHTTPRedirection = { session, task, response, request in return nil }
            
            self.isolatedManagerMap[sessionId] = manager
            
            return manager
        }
    }
}

private struct DataBodyParameterEncoding: ParameterEncoding
{
    let body: Data
    func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest
    {
        var urlRequest = try urlRequest.asURLRequest()
        urlRequest.httpBody = body
        return urlRequest
    }
}

private struct ResponseMethod<TResponse>
{
    let invocation: (_ request: DataRequest, _ queue: DispatchQueue?, _ completionHandler: @escaping (DataResponse<TResponse>) -> Void) -> ()
}
