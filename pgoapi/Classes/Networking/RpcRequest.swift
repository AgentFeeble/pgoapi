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
    let params: RpcParams
    
    var encryptFunc: PgoEncryption.EncryptFunction?
    
    init(network: Network, params: RpcParams, messages: [RequestMessage])
    {
        precondition(messages.count > 0)
        
        self.network = network
        self.messages = messages
        self.params = params
    }
    
    func execute<T, C>(_ endPoint: String, decoder: Decoder<T, C>) -> Task<T>
    {
        guard let encryptFunc = PgoEncryption.encrypt else
        {
            return Task(error: PgoApi.ApiError.noEncryptionFuncProvided)
        }
        self.encryptFunc = encryptFunc
        
        // Note: self is captured strongly to keep the instance alive
        // for the duration of the API call
        return Task(network.processingExecutor, closure:
        {
            return self.buildRequestEnvelope().data()
        })
        .continueOnSuccessWithTask(continuation:
        {
            (requestData: Data) -> Task<NetworkResponse<Data>> in
            let args = RequestArgs(params: [:], body: requestData)
            return self.network.postData(endPoint, args: args)
        })
        .continueOnSuccessWith(network.processingExecutor, continuation:
        {
            (response: NetworkResponse<Data>) -> T in
            return try self.process(response: response, decoder: decoder)
        })
    }
    
    fileprivate func buildRequestEnvelope() -> Pogoprotos.Networking.Envelopes.RequestEnvelope
    {
        let requestBuilder = Pogoprotos.Networking.Envelopes.RequestEnvelope.Builder()
        requestBuilder.statusCode = 2
        requestBuilder.requestId = params.requestId
        requestBuilder.accuracy = 10
        
        if let location = params.location
        {
            requestBuilder.latitude = location.latitude
            requestBuilder.longitude = location.longitude
        }
        
        // Force unwrap try statements - we want the app to crash if the request can't be generated
        try! buildMessages(forRequest: requestBuilder)
        
        if let ticket = params.authTicket
        {
            let authTicketBuilder = requestBuilder.getAuthTicketBuilder()
            authTicketBuilder.expireTimestampMs = ticket.expireTimestamp_ms
            authTicketBuilder.start = ticket.start
            authTicketBuilder.end = ticket.end
            
            let ticketData = try! authTicketBuilder.build().data()
            let sigBuilder = Pogoprotos.Networking.Envelopes.Signature.Builder()
            sigBuilder.locationHash1 = generateLocation1(ticket: ticketData,
                                                         lat: requestBuilder.latitude,
                                                         lng: requestBuilder.longitude,
                                                         altitude: params.location?.altitude ?? 0.0)
            sigBuilder.locationHash2 = generateLocation2(lat: requestBuilder.latitude,
                                                         lng: requestBuilder.longitude,
                                                         altitude: params.location?.altitude ?? 0.0)
            
            for request in requestBuilder.requests
            {
                let hash = generateRequestHash(ticket: ticketData, requestData: request.data())
                sigBuilder.requestHash.append(hash)
            }

            // TODO: update for compatibility with API version 0.43.3
//            sigBuilder.field22 = randomBytes(length: 32)
//            sigBuilder.timestamp = UInt64(Date().timeIntervalSince1970 * 1000.0)
//            sigBuilder.timestampSinceStart = (sigBuilder.timestamp > params.sessionStartTime) ? sigBuilder.timestamp - params.sessionStartTime : 0
//            
//            let signature = try! sigBuilder.build()
//            let u6Builder = requestBuilder.getUnknown6Builder()
//            let u2Builder = u6Builder.getUnknown2Builder()
//            
//            u6Builder.requestType = Constant.unknown6RequestId
//            u2Builder.encryptedSignature = generateSignatureData(signature)
        }
        else
        {
            // No session ticket; use the OAuth access token instead
            let authInfoBuilder = requestBuilder.getAuthInfoBuilder()
            authInfoBuilder.provider = "ptc"
            
            let authInfoTokenBuilder = authInfoBuilder.getTokenBuilder()
            authInfoTokenBuilder.contents = params.authToken.token
            authInfoTokenBuilder.unknown2 = Constant.Unknown2
        }
        
        return try! requestBuilder.build()
    }
    
    fileprivate func buildMessages(forRequest request: Pogoprotos.Networking.Envelopes.RequestEnvelope.Builder) throws
    {
        for message in messages
        {
            let messageBuilder = Pogoprotos.Networking.Requests.Request.Builder()
            messageBuilder.requestType = message.type
            messageBuilder.requestMessage = message.message.data()
            request.requests.append(try messageBuilder.build())
        }
    }
    
    fileprivate func generateSignatureData(_ signature: Pogoprotos.Networking.Envelopes.Signature) -> Data
    {
        let signatureData = signature.data()
        let iv = randomBytes(length: 32)
        
        let encryptFunc = self.encryptFunc!
        return encryptFunc(signatureData, iv)
    }
    
    fileprivate func process<T, C>(response: NetworkResponse<Data>, decoder: Decoder<T, C>) throws -> T
    {
        guard response.statusCode == 200 else
        {
            throw NetworkError.invalidStatusCode(response.statusCode)
        }
        guard let responseData = response.response else
        {
            throw NetworkError.invalidResponse
        }
        
        do
        {
            return try decoder.decode(responseData)
        }
        catch let error
        {
            throw NetworkError.deserializationError(error)
        }
    }
}
