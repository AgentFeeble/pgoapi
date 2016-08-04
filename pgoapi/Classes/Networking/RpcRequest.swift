//
//  RpcRequest.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/27.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation
import BoltsSwift

class RpcRequest
{
    let network: Network
    let messages: [RequestMessage]
    let authToken: AuthToken
    let location: Location?
    
    init(network: Network, params: RpcParams, messages: [RequestMessage])
    {
        precondition(messages.count > 0)
        
        self.network = network
        self.messages = messages
        authToken = params.authToken
        location = params.location
    }
    
    func execute<T, C>(endPoint: String, decoder: Decoder<T, C>) -> Task<T>
    {
        // Note: self is captured strongly to keep the instance alive
        // for the duration of the API call
        return Task(network.processingExecutor, closure:
        {
            return self.buildRequestEnvelope().data()
        })
        .continueOnSuccessWithTask(continuation:
        {
            (requestData: NSData) -> Task<NetworkResponse<NSData>> in
            return self.network.postData(endPoint, args: RequestArgs(params: [:], body: requestData))
        })
        .continueOnSuccessWith(network.processingExecutor, continuation:
        {
            (response: NetworkResponse<NSData>) -> T in
            return try self.process(response, decoder: decoder)
        })
    }
    
    private func buildRequestEnvelope() -> Pogoprotos.Networking.Envelopes.RequestEnvelope
    {
        let requestBuilder = Pogoprotos.Networking.Envelopes.RequestEnvelope.Builder()
        requestBuilder.statusCode = 2
        requestBuilder.requestId = Constant.ApiRequestID
        requestBuilder.unknown12 = Constant.Unknown12
        
        if let location = location
        {
            requestBuilder.latitude = location.latitude
            requestBuilder.longitude = location.longitude
            requestBuilder.altitude = location.altitude
        }
        
        let authInfoBuilder = requestBuilder.getAuthInfoBuilder()
        authInfoBuilder.provider = "ptc"
        
        let authInfoTokenBuilder = authInfoBuilder.getTokenBuilder()
        authInfoTokenBuilder.contents = authToken.token
        authInfoTokenBuilder.unknown2 = Constant.Unknown2
        
        // Force unwrap try statements - we want the app to crash if the request can't be generated
        for message in messages
        {
            let messageBuilder = Pogoprotos.Networking.Requests.Request.Builder()
            messageBuilder.requestType = message.type
            messageBuilder.requestMessage = message.message.data()
            requestBuilder.requests += [try! messageBuilder.build()]
        }
        
        return try! requestBuilder.build()
    }
    
    private func process<T, C>(response: NetworkResponse<NSData>, decoder: Decoder<T, C>) throws -> T
    {
        guard response.statusCode == 200 else
        {
            throw NetworkError.InvalidStatusCode(response.statusCode)
        }
        guard let responseData = response.response else
        {
            throw NetworkError.InvalidResponse
        }
        
        do
        {
            return try decoder.decode(responseData)
        }
        catch let error
        {
            throw NetworkError.DeserializationError(error)
        }
    }
}
