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

public class PgoApi
{
    public enum ApiError: ErrorType
    {
        case NotLoggedIn
    }
    
    final public class Builder
    {
        private let api: PgoApi
        private let authToken: AuthToken
        private var messages: [RequestMessage] = []
        
        private var responseConverterBuilder = ApiResponseDataConverter.Builder()
        
        private let location: Location?
        
        private init(api: PgoApi, authToken: AuthToken, location: Location?)
        {
            self.api = api
            self.authToken = authToken
            self.location = location
        }
    }
    
    public let network: Network
    let authToken: AuthToken
    
    private var apiEndpoint: String?
    private(set) var loggedIn = false
    private var lock: OSSpinLock = OS_SPINLOCK_INIT
    
    public init(network: Network, authToken: AuthToken)
    {
        self.network = network
        self.authToken = authToken
    }
    
    public func builder(location: Location? = nil) -> Builder
    {
        return Builder(api: self, authToken: authToken, location: location)
    }
    
    public func login() -> Task<(PgoApi, ApiResponse)>
    {
        // Capture self strongly, so that the instance stays alive until the login call finishes
        return executeInternal(builder: getLoginBuilder())
        .continueOnSuccessWith(network.processingExecutor)
        {
            response in
            self.sync
            {
                self.apiEndpoint = "https://\(response.response.apiUrl)/rpc"
                self.loggedIn = true
            }
            return (self, response)
        }
    }
    
    public func execute(builder: Builder) -> Task<ApiResponse>
    {
        let (isLoggedIn, endPoint) = sync { return (loggedIn, apiEndpoint) }
        
        guard isLoggedIn else
        {
            return Task(error: ApiError.NotLoggedIn)
        }
        // Explicityly force unwrap apiEndpoint. If we don't have one after being logged in, the app is in an inconsistent state
        return executeInternal(endPoint!, builder: builder)
    }
    
    private func executeInternal(endPoint: String = EndPoint.Rpc, builder: Builder) -> Task<ApiResponse>
    {
        let request = builder.build()
        return request.request.execute(endPoint, decoder: request.decoder)
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
    
    private func sync(@noescape closure: () -> ())
    {
        OSSpinLockLock(&lock)
        defer { OSSpinLockUnlock(&lock) }
        closure()
    }
    
    private func sync<T>(@noescape closure: () -> T) -> T
    {
        OSSpinLockLock(&lock)
        defer { OSSpinLockUnlock(&lock) }
        return closure()
    }
}

private extension PgoApi.Builder
{
    func build() -> (request: RpcRequest, decoder: Decoder<ApiResponse, ApiResponseDataConverter>)
    {
        let params = RpcParams(authToken: authToken, location: location)
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
