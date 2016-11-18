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

open class PgoApi: Synchronizable
{
    public enum ApiError: Error
    {
        case notLoggedIn
        case noEncryptionFuncProvided
        case invalidStatusCode(ApiResponse)
    }
    
    final public class Builder
    {
        fileprivate let api: PgoApi
        fileprivate var messages: [RequestMessage] = []
        
        fileprivate var responseConverterBuilder = ApiResponseDataConverter.Builder()
        
        fileprivate let location: Location?
        
        fileprivate init(api: PgoApi, location: Location?)
        {
            self.api = api
            self.location = location
        }
        
        // Copy
        fileprivate init(builder: Builder)
        {
            self.api = builder.api
            self.location = builder.location
            self.messages = builder.messages
            self.responseConverterBuilder = builder.responseConverterBuilder
        }
    }
    
    open let network: Network
    fileprivate let authToken: AuthToken
    
    fileprivate var requestId: UInt64 = 0
    fileprivate var sessionStartTime: UInt64?
    fileprivate var authTicket: AuthTicket?
    fileprivate var apiEndpoint: String?
    
    let synchronizationLock: Lockable = SpinLock()
    
    public init(network: Network, authToken: AuthToken)
    {
        self.network = network
        self.authToken = authToken
    }
    
    open func builder(_ location: Location? = nil) -> Builder
    {
        return Builder(api: self, location: location)
    }
    
    /// This function isn't needed anymore before other API calls can be made
    open func login() -> Task<(PgoApi, ApiResponse)>
    {
        // Capture self strongly, so that the instance stays alive until the login call finishes
        return executeInternal(builder: getLoginBuilder(), redirectsAllowed: 3)
        .continueOnSuccessWith(network.processingExecutor)
        {
            response in
            return (self, response)
        }
    }
    
    open func execute(_ builder: Builder) -> Task<ApiResponse>
    {
        let endPoint = sync { return apiEndpoint } ?? EndPoint.Rpc
        let redirectsAllowed = 3
        
        return executeInternal(endPoint, builder: builder, redirectsAllowed: redirectsAllowed)
    }
    
    fileprivate func executeInternal(_ endPoint: String = EndPoint.Rpc, builder: Builder, redirectsAllowed: Int) -> Task<ApiResponse>
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
                switch (response.response.statusCode)
                {
                case .ok, .okRpcUrlInResponse:
                    return Task(response)
                    
                case .redirect where redirectsAllowed > 0:
                    self.processRedirect(response)
                    return self.executeInternal(self.apiEndpoint ?? endPoint,
                                                builder: builderCopy,
                                                redirectsAllowed: redirectsAllowed - 1)
                    
                default:
                    return Task(error: ApiError.invalidStatusCode(response))
                }
            })
        })
    }

    // This method is not thread safe. Only invoke from within a thread safe context
    fileprivate func getRequestId() -> UInt64
    {
        let rand: UInt64
        if requestId == 0
        {
            rand = 0x000041A7
        }
        else
        {
            rand = UInt64(arc4random())
        }
        
        requestId += 1
        let count = requestId
        let id = ((rand | ((count & 0xFFFFFFFF) >> 31)) << 32)
        
        return id
    }
    
    // This method is not thread safe. Only invoke from within a thread safe context
    fileprivate func getSessionStartTime() -> UInt64
    {
        if let startTime = sessionStartTime
        {
            return startTime
        }
        
        let startTime = UInt64(Date().timeIntervalSince1970 * 1000.0)
        sessionStartTime = startTime
        return startTime
    }
    
    fileprivate func getLoginBuilder() -> Builder
    {
        return builder()
              .getPlayer()
              .getHatchedEggs()
              .getInventory()
              .checkAwardedBadges()
              .downloadSettings()
    }
    
    fileprivate func extractAuthTicket(_ response: ApiResponse)
    {
        if !response.response.hasAuthTicket
        {
            return
        }
        
        if let ticket = response.response.authTicket
        {
            sync
            {
                authTicket = AuthTicket(expireTimestamp_ms: ticket.expireTimestampMs, start: ticket.start, end: ticket.end)
            }
        }
    }
    
    fileprivate func processRedirect(_ response: ApiResponse)
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
    func build(_ requestId: UInt64, sessionStartTime: UInt64, ticket: AuthTicket?) -> (request: RpcRequest, decoder: Decoder<ApiResponse, ApiResponseDataConverter>)
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
    fileprivate typealias RequestType = Pogoprotos.Networking.Requests.RequestType
    
    /// Force unwrap all building. It should be a runtime error for a builder not to build
    
    public func getPlayer() -> PgoApi.Builder
    {
        let responseType = Pogoprotos.Networking.Responses.GetPlayerResponse.self
        let messageBuilder = Pogoprotos.Networking.Requests.Messages.GetPlayerMessage.Builder()
        return addMessage(try! messageBuilder.build(), type: .getPlayer, responseType: responseType)
    }

    func getHatchedEggs() -> PgoApi.Builder
    {
        let responseType = Pogoprotos.Networking.Responses.GetHatchedEggsResponse.self
        let messageBuilder = Pogoprotos.Networking.Requests.Messages.GetHatchedEggsMessage.Builder()
        return addMessage(try! messageBuilder.build(), type: .getHatchedEggs, responseType: responseType)
    }

    func getInventory() -> PgoApi.Builder
    {
        let responseType = Pogoprotos.Networking.Responses.GetInventoryResponse.self
        let messageBuilder = Pogoprotos.Networking.Requests.Messages.GetInventoryMessage.Builder()
        return addMessage(try! messageBuilder.build(), type: .getInventory, responseType: responseType)
    }
    
    func checkAwardedBadges() -> PgoApi.Builder
    {
        let responseType = Pogoprotos.Networking.Responses.CheckAwardedBadgesResponse.self
        let messageBuilder = Pogoprotos.Networking.Requests.Messages.CheckAwardedBadgesMessage.Builder()
        return addMessage(try! messageBuilder.build(), type: .checkAwardedBadges, responseType: responseType)
    }
    
    func downloadSettings() -> PgoApi.Builder
    {
        let responseType = Pogoprotos.Networking.Responses.DownloadSettingsResponse.self
        let messageBuilder = Pogoprotos.Networking.Requests.Messages.DownloadSettingsMessage.Builder()
        messageBuilder.hash = Constant.SettingsHash
        
        return addMessage(try! messageBuilder.build(), type: .downloadSettings, responseType: responseType)
    }
    
    /// This API request requires the location to be set
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
        messageBuilder.sinceTimestampMs = [Int64](repeating: 0, count: cellIDs.count)
        messageBuilder.latitude = location.latitude
        messageBuilder.longitude = location.longitude
        
        return addMessage(try! messageBuilder.build(), type: .getMapObjects, responseType: responseType)
    }
    
    /// This API request requires the location to be set
    func encounterPokemon(encounterId: UInt64, spawnPointId: String) -> PgoApi.Builder
    {
        guard let location = location else
        {
            fatalError("location must be set to encounter a pokemon")
        }
        
        let responseType = Pogoprotos.Networking.Responses.EncounterResponse.self
        let messageBuilder = Pogoprotos.Networking.Requests.Messages.EncounterMessage.Builder()
        
        messageBuilder.encounterId = encounterId
        messageBuilder.spawnPointId = spawnPointId
        messageBuilder.playerLatitude = location.latitude
        messageBuilder.playerLongitude = location.longitude
        
        return addMessage(try! messageBuilder.build(), type: .encounter, responseType: responseType)
    }
    
    fileprivate func addMessage<T: GeneratedMessage>
                           (_ message: GeneratedMessage, type: RequestType, responseType: T.Type) -> PgoApi.Builder where T: GeneratedMessageProtocol
    {
        let requestMessage = RequestMessage(type: type, message: message)
        let convertMethod: (_ data: Data) throws -> T = responseType.parseFrom(data:)
        
        messages.append(requestMessage)
        responseConverterBuilder.addSubResponseConverter(type, converter: ProtoBufDataConverter(convertFunc: convertMethod))
        return self
    }
    
    public func execute() -> Task<ApiResponse>
    {
        return api.execute(self)
    }
}
