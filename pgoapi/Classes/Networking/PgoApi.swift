//
//  PgoApi.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/28.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation
import BoltsSwift
import ProtocolBuffers

public class PgoApi: Synchronizable
{
    public enum ApiError: ErrorType
    {
        case NotLoggedIn
        case NoEncryptionFuncProvided
        case InvalidStatusCode(ApiResponse)
    }
    
    public enum ApiStatusCode: Int32
    {
        case AuthTokenExpired = 102
        case RequestThrottled = 52
        case RedirectRequest = 53
    }
    
    final public class Builder
    {
        private let api: PgoApi
        private var messages: [RequestMessage] = []
        
        private var responseConverterBuilder = ApiResponseDataConverter.Builder()
        
        private let location: Location?
        
        private init(api: PgoApi, location: Location?)
        {
            self.api = api
            self.location = location
        }
        
        // Copy
        private init(builder: Builder)
        {
            self.api = builder.api
            self.location = builder.location
            self.messages = builder.messages
            self.responseConverterBuilder = builder.responseConverterBuilder
        }
    }
    
    public let network: Network
    private let authToken: AuthToken
    
    private var requestId: UInt64?
    private var sessionStartTime: UInt64?
    private var authTicket: AuthTicket?
    private var apiEndpoint: String?
    
    let synchronizationLock: Lockable = SpinLock()
    
    public init(network: Network, authToken: AuthToken)
    {
        self.network = network
        self.authToken = authToken
    }
    
    public func builder(location: Location? = nil) -> Builder
    {
        return Builder(api: self, location: location)
    }
    
    /// This function isn't needed anymore before other API calls can be made
    public func login() -> Task<(PgoApi, ApiResponse)>
    {
        // Capture self strongly, so that the instance stays alive until the login call finishes
        return executeInternal(builder: getLoginBuilder(), redirectsAllowed: 3)
        .continueOnSuccessWith(network.processingExecutor)
        {
            response in
            return (self, response)
        }
    }
    
    public func execute(builder: Builder) -> Task<ApiResponse>
    {
        let endPoint = sync { return apiEndpoint } ?? EndPoint.Rpc
        let redirectsAllowed = 3
        
        return executeInternal(endPoint, builder: builder, redirectsAllowed: redirectsAllowed)
    }
    
    private func executeInternal(endPoint: String = EndPoint.Rpc, builder: Builder, redirectsAllowed: Int) -> Task<ApiResponse>
    {
        let network = self.network
        let builderCopy = Builder(builder: builder)
        
        return Task.executeWithTask(network.processingExecutor, closure:
        {
            _ in
            let (requestId, sessionStartTime, ticket) = self.sync
            {
                return (self.getRequestId(), self.getSessionStartTime(), self.authTicket)
            }
            
            let request = builderCopy.build(requestId, sessionStartTime: sessionStartTime, ticket: ticket)
            return request.request.execute(endPoint, decoder: request.decoder)
            .continueOnSuccessWithTask(network.processingExecutor, continuation:
            {
                response in
                
                self.extractAuthTicket(response)
                if let status = ApiStatusCode(rawValue: response.response.statusCode)
                {
                    if status == ApiStatusCode.RedirectRequest && redirectsAllowed > 0
                    {
                        self.processRedirect(response)
                        return self.executeInternal(self.apiEndpoint ?? endPoint,
                                                    builder: builderCopy,
                                                    redirectsAllowed: redirectsAllowed - 1)
                    }
                    
                    return Task(error: ApiError.InvalidStatusCode(response))
                }
                return Task(response)
            })
        })
    }
    
    // This method is not thread safe. Only invoke from within a thread safe context
    private func getRequestId() -> UInt64
    {
        if let requestId = requestId
        {
            let newId = requestId + 1
            self.requestId = newId
            return newId
        }
        
        let rDouble = Double(arc4random()) / Double(UInt32.max) // range [0.0, 1.0]
        let newId = UInt64(rDouble * pow(10, 18)) // random 18 digit number
        self.requestId = newId
        
        return newId
    }
    
    // This method is not thread safe. Only invoke from within a thread safe context
    private func getSessionStartTime() -> UInt64
    {
        if let startTime = sessionStartTime
        {
            return startTime
        }
        
        let startTime = UInt64(NSDate().timeIntervalSince1970 * 1000.0)
        sessionStartTime = startTime
        return startTime
    }
    
    private func getLoginBuilder() -> Builder
    {
        return builder()
              .getPlayer()
              .getHatchedEggs()
              .getInventory()
              .checkAwardedBadges()
              .downloadSettings()
    }
    
    private func extractAuthTicket(response: ApiResponse)
    {
        if !response.response.hasAuthTicket
        {
            return
        }
        
        let ticket = response.response.authTicket
        sync { authTicket = AuthTicket(expireTimestamp_ms: ticket.expireTimestampMs, start: ticket.start, end: ticket.end) }
    }
    
    private func processRedirect(response: ApiResponse)
    {
        if response.response.hasApiUrl
        {
            sync
            {
                apiEndpoint = "https://\(response.response.apiUrl)/rpc"
            }
        }
    }
}

private extension PgoApi.Builder
{
    func build(requestId: UInt64, sessionStartTime: UInt64, ticket: AuthTicket?) -> (request: RpcRequest, decoder: Decoder<ApiResponse, ApiResponseDataConverter>)
    {
        let params = RpcParams(authToken: api.authToken, requestId: requestId, sessionStartTime: sessionStartTime, authTicket: ticket, location: location)
        let request = RpcRequest(network: api.network, params: params, messages: messages)
        let decoder = Decoder(converter: responseConverterBuilder.build())
        
        return (request: request, decoder: decoder)
    }
}

// This extensions adds all the methods to build up the response
public extension PgoApi.Builder
{
    private typealias RequestType = Pogoprotos.Networking.Requests.RequestType
    
    /// Force unwrap all building. It should be a runtime error for a builder not to build
    
    public func getPlayer() -> PgoApi.Builder
    {
        let messageBuilder = Pogoprotos.Networking.Requests.Messages.GetPlayerMessage.Builder()
        let responseType = Pogoprotos.Networking.Responses.GetPlayerResponse.self
        return addMessage(try! messageBuilder.build(), type: .GetPlayer, responseType: responseType)
    }

    func getHatchedEggs() -> PgoApi.Builder
    {
        let messageBuilder = Pogoprotos.Networking.Requests.Messages.GetHatchedEggsMessage.Builder()
        let responseType = Pogoprotos.Networking.Responses.GetHatchedEggsResponse.self
        return addMessage(try! messageBuilder.build(), type: .GetHatchedEggs, responseType: responseType)
    }

    func getInventory() -> PgoApi.Builder
    {
        let messageBuilder = Pogoprotos.Networking.Requests.Messages.GetInventoryMessage.Builder()
        let responseType = Pogoprotos.Networking.Responses.GetInventoryResponse.self
        return addMessage(try! messageBuilder.build(), type: .GetInventory, responseType: responseType)
    }
    
    func checkAwardedBadges() -> PgoApi.Builder
    {
        let messageBuilder = Pogoprotos.Networking.Requests.Messages.CheckAwardedBadgesMessage.Builder()
        let responseType = Pogoprotos.Networking.Responses.CheckAwardedBadgesResponse.self
        return addMessage(try! messageBuilder.build(), type: .CheckAwardedBadges, responseType: responseType)
    }
    
    func downloadSettings() -> PgoApi.Builder
    {
        let messageBuilder = Pogoprotos.Networking.Requests.Messages.DownloadSettingsMessage.Builder()
        messageBuilder.hash = Constant.SettingsHash
        let responseType = Pogoprotos.Networking.Responses.DownloadSettingsResponse.self
        return addMessage(try! messageBuilder.build(), type: .DownloadSettings, responseType: responseType)
    }
    
    func getMapObjects() -> PgoApi.Builder
    {
        guard let location = location else
        {
            fatalError("location must be set to get map objects")
        }
        
        let messageBuilder = Pogoprotos.Networking.Requests.Messages.GetMapObjectsMessage.Builder()
        let responseType = Pogoprotos.Networking.Responses.GetMapObjectsResponse.self
        let cellIDs = getCellIDs(location)
        
        messageBuilder.cellId = cellIDs
        messageBuilder.sinceTimestampMs = [Int64](count: cellIDs.count, repeatedValue: 0)
        messageBuilder.latitude = location.latitude
        messageBuilder.longitude = location.longitude
        
        return addMessage(try! messageBuilder.build(), type: .GetMapObjects, responseType: responseType)
    }
    
    private func addMessage<T: GeneratedMessage where T: GeneratedMessageProtocol>
                           (message: GeneratedMessage, type: RequestType, responseType: T.Type) -> PgoApi.Builder
    {
        let requestMessage = RequestMessage(type: type, message: message)
        let convertMethod: (data: NSData) throws -> T = responseType.parseFromData
        
        messages.append(requestMessage)
        responseConverterBuilder.addSubResponseConverter(type, converter: ProtoBufDataConverter(convertFunc: convertMethod))
        return self
    }
    
    public func execute() -> Task<ApiResponse>
    {
        return api.execute(self)
    }
}
