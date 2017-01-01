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
    
    var encryptFunc: PgoEncryption.EncryptFunction!
    let hasher: HashGenerator
    
    private typealias RequestBuilder = Pogoprotos.Networking.Envelopes.RequestEnvelope.Builder
    
    init(network: Network, hasher: HashGenerator, params: RpcParams, messages: [RequestMessage])
    {
        precondition(messages.count > 0)
        
        self.network = network
        self.hasher = hasher
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
        return Task.executeWithTask(network.processingExecutor, closure:
        {
            return self.buildRequestEnvelope()
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
    
    private func newRandomAccuracyValue() -> Double
    {
        let r = Random.getDouble(min: 66, range: 14)
        let choices: [Double] = [ 5.0, 5.0, 5.0, 5.0, 10.0, 10.0, 10.0, 30.0, 30.0, 50.0, 65.0, r ]
        return Random.choice(choices)
    }
    
    private func buildRequestEnvelope() -> Task<Data>
    {
        let requestBuilder = RequestBuilder()
        requestBuilder.statusCode = 2
        requestBuilder.requestId = params.requestId
        requestBuilder.accuracy = newRandomAccuracyValue()
        
        if let location = params.location
        {
            requestBuilder.latitude = location.latitude
            requestBuilder.longitude = location.longitude
        }
        
        // Force unwrap try statements - we want the app to crash if the request can't be generated
        try! buildMessagesFor(request: requestBuilder)
        let ticketData: Data
        
        if let ticket = params.authTicket
        {
            let authTicketBuilder = requestBuilder.getAuthTicketBuilder()
            authTicketBuilder.expireTimestampMs = ticket.expireTimestamp_ms
            authTicketBuilder.start = ticket.start
            authTicketBuilder.end = ticket.end
            
            ticketData = requestBuilder.authTicket.data()
        }
        else
        {
            let authInfoBuilder = requestBuilder.getAuthInfoBuilder()
            authInfoBuilder.provider = "ptc"
            
            let authInfoTokenBuilder = authInfoBuilder.getTokenBuilder()
            authInfoTokenBuilder.contents = params.authToken.token
            authInfoTokenBuilder.unknown2 = Constant.Unknown2
            
            ticketData = requestBuilder.authInfo.data()
        }
        
        requestBuilder.msSinceLastLocationfix = Int64(Random.triangular(min: 300, max: 30000, mode: 10000))
        return signRequestBuilder(authData: ticketData, requestBuilder: requestBuilder, altitude: params.location?.altitude)
        .continueOnSuccessWith(network.processingExecutor)
        {
            (builder: RpcRequest.RequestBuilder) -> Data in
            return try! requestBuilder.build().data()
        }
    }
    
    private func buildMessagesFor(request: Pogoprotos.Networking.Envelopes.RequestEnvelope.Builder) throws
    {
        for message in messages
        {
            let messageBuilder = Pogoprotos.Networking.Requests.Request.Builder()
            messageBuilder.requestType = message.type
            messageBuilder.requestMessage = message.message.data()
            request.requests.append(try messageBuilder.build())
        }
    }
    
    private func signRequestBuilder(authData: Data, requestBuilder: RequestBuilder, altitude: Double?) -> Task<RequestBuilder>
    {
        let sigBuilder = Pogoprotos.Networking.Envelopes.SignalAgglomUpdates.Builder()
        
        sigBuilder.field22 = Random.randomBytes(length: 16)
        sigBuilder.epochTimestampMs = UInt64(Date().timeIntervalSince1970 * 1000.0)
        sigBuilder.timestampMsSinceStart = Int64(bitPattern: sigBuilder.epochTimestampMs - params.sessionStartTime)
        if sigBuilder.timestampMsSinceStart < 5000
        {
            sigBuilder.timestampMsSinceStart = Int64(Random.getInt(min: 5000, range: 3000))
        }
        
        let locBuilder = Pogoprotos.Networking.Envelopes.SignalAgglomUpdates.LocationUpdate.Builder()
        let senBuilder = Pogoprotos.Networking.Envelopes.SignalAgglomUpdates.SensorUpdate.Builder()
        
        if let altitude = altitude
        {
            locBuilder.altitude = Float(altitude)
        }
        else
        {
            locBuilder.altitude = Float(Random.triangular(min: 300.0, max: 400.0, mode: 350.0))
        }
        
        // no reading for roughly 1 in 20 updates
        if Random.getInt(min: 0, range: 100) > 95
        {
            locBuilder.deviceCourse = -1.0
            locBuilder.deviceSpeed = -1.0
        }
        else
        {
            let mode = Random.getDouble(min: 0, range: 360)
            locBuilder.deviceCourse = Float(Random.triangular(min: 0.0, max: 360.0, mode: mode))
            locBuilder.deviceSpeed = Float(Random.triangular(min: 0.2, max: 4.25, mode: 1.0))
        }
        
        locBuilder.providerStatus = 3
        locBuilder.locationType = 1
        if requestBuilder.accuracy >= 65
        {
            locBuilder.verticalAccuracy = Float(Random.triangular(min: 35.0, max: 100.0, mode: 65.0))
            locBuilder.horizontalAccuracy = Float(Random.choice([ requestBuilder.accuracy, 65.0, 65.0, Random.getDouble(min: 66, range: 14), 200 ]))
        }
        else
        {
            if requestBuilder.accuracy > 10
            {
                locBuilder.verticalAccuracy = Random.choice([ 24, 32, 48, 48, 64, 64, 96, 128 ])
            }
            else
            {
                locBuilder.verticalAccuracy = Random.choice([ 3, 4, 6, 6, 8, 12, 24 ])
            }
            locBuilder.horizontalAccuracy = Float(requestBuilder.accuracy)
        }
        
        senBuilder.accelerationX = Random.triangular(min: -3.0, max: 1.0, mode: 0.0)
        senBuilder.accelerationY = Random.triangular(min: -2.0, max: 3.0, mode: 0.0)
        senBuilder.accelerationZ = Random.triangular(min: -4.0, max: 2.0, mode: 0.0)
        senBuilder.magneticFieldX = Random.triangular(min: -50.0, max: 50.0, mode: 0.0)
        senBuilder.magneticFieldY = Random.triangular(min: -60.0, max: 50.0, mode: -5.0)
        senBuilder.magneticFieldZ = Random.triangular(min: -60.0, max: 40.0, mode: -30.0)
        senBuilder.magneticFieldAccuracy = Random.choice([ -1, 1, 1, 2, 2, 2, 2 ])
        senBuilder.attitudePitch = Random.triangular(min: -1.5, max: 1.5, mode: 0.2)
        senBuilder.attitudeYaw = Random.getDouble(min: -3, range: 3)
        senBuilder.attitudeRoll = Random.triangular(min: -2.8, max: 2.5, mode: 0.25)
        senBuilder.rotationRateX = Random.triangular(min: -6.0, max: 4.0, mode: 0.0)
        senBuilder.rotationRateY = Random.triangular(min: -5.5, max: 5.0, mode: 0.0)
        senBuilder.rotationRateZ = Random.triangular(min: -5.0, max: 3.0, mode: 0.0)
        senBuilder.gravityX = Random.triangular(min: -1.0, max: 1.0, mode: 0.15)
        senBuilder.gravityY = Random.triangular(min: -1.0, max: 1.0, mode: -0.2)
        senBuilder.gravityZ = Random.triangular(min: -1.0, max: 0.7, mode: -0.8)
        senBuilder.status = 3
        
        sigBuilder.field25 =  hasher.unknown25
        
        let deviceInfoBuilder = sigBuilder.getIosDeviceInfoBuilder()
        deviceInfoBuilder.bool5 = true
        
        sigBuilder.locationUpdates.append(try! locBuilder.build())
        sigBuilder.sensorUpdates.append(try! senBuilder.build())
        
        return hasher.generateHash(timestamp: sigBuilder.epochTimestampMs,
                                   latitude: requestBuilder.latitude,
                                   longitude: requestBuilder.longitude,
                                   altitude: requestBuilder.accuracy,
                                   authTicket: authData,
                                   sessionData: sigBuilder.field22,
                                   requests: requestBuilder.requests.map({ $0.data() }))
        .continueOnSuccessWith(network.processingExecutor)
        {
            (result: HashResult) -> RequestBuilder in
            
            let sigRequestBuilder = Pogoprotos.Networking.Platform.Requests.SendEncryptedSignatureRequest.Builder()
            let platformRequestBuilder = Pogoprotos.Networking.Envelopes.RequestEnvelope.PlatformRequest.Builder()
            
            let signedRequestHashes = result.requestHashes.map({ Int64(bitPattern: $0) })
            
            sigBuilder.locationHashByTokenSeed = result.locationAuthHash
            sigBuilder.locationHash = result.locationHash
            sigBuilder.requestHashes.append(contentsOf: signedRequestHashes)
            
            requestBuilder.platformRequests.append(try! platformRequestBuilder.build())
            
            sigRequestBuilder.encryptedSignature = self.generateSignatureData(try! sigBuilder.build())
            platformRequestBuilder.type = .sendEncryptedSignature
            platformRequestBuilder.requestMessage = try! sigRequestBuilder.build().data()
            
            return requestBuilder
        }
    }
    
    private func generateSignatureData(_ signature: Pogoprotos.Networking.Envelopes.SignalAgglomUpdates) -> Data
    {
        let signatureData = signature.data()
        let iv = UInt32(signature.timestampMsSinceStart)
        
        let encryptFunc = self.encryptFunc!
        return encryptFunc(signatureData, iv)
    }
    
    private func process<T, C>(response: NetworkResponse<Data>, decoder: Decoder<T, C>) throws -> T
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
