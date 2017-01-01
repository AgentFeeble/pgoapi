//
//  PokeFarmerHashGenerator.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2017/01/01.
//  Copyright © 2017 MC. All rights reserved.
//

import BoltsSwift
import Foundation

public class PokeFarmerHashGenerator: HashGenerator
{
    public enum Error: Swift.Error
    {
        case BadRequest
        case Forbidden
        case QuotaExceeded
        case ServerError
        case InvalidResponse
    }
    
    let network: Network
    let apiKey: String
    
    private let endpoint = "https://pokehash.buddyauth.com/api/v121_2/hash"
    private let sessionID = "PokeFarmerHashGenerator.Session"
    
    public let unknown25: UInt64 = UInt64(bitPattern: -8832040574896607694)
    
    public init(network: Network, apiKey: String)
    {
        self.network = network
        self.apiKey = apiKey
    }
    
    public func generateHash(timestamp: UInt64,
                      latitude: Double,
                      longitude: Double,
                      altitude: Double,
                      authTicket: Data,
                      sessionData: Data,
                      requests: [Data]) -> Task<HashResult>
    {
        let network = self.network
        let apiKey = self.apiKey
        let sessionID = self.sessionID
        let endpoint = self.endpoint
        
        return Task.executeWithTask(network.processingExecutor)
        {
            let headers: [String: String] = [
                "content-type": "application/json",
                "User-Agent":   "Swift pgoapi @AgentFeeble",
                "X-AuthToken":  apiKey,
                "Accept":       "application/json"
            ]
            let payload: [String: Any] = [
                "Timestamp":   timestamp,
                "Latitude":    latitude,
                "Longitude":   longitude,
                "Altitude":    altitude,
                "AuthTicket":  authTicket.base64EncodedString(),
                "SessionData": sessionData.base64EncodedString(),
                "Requests":    requests.map({ $0.base64EncodedString() })
            ]
            
            let body = try JSONSerialization.data(withJSONObject: payload, options: JSONSerialization.WritingOptions())
            let args = RequestArgs(headers: headers, params: nil, body: body, sessionId: sessionID)
            return network.postData(endpoint, args: args)
        }
        .continueOnSuccessWith(network.processingExecutor)
        {
            (response: NetworkResponse<Data>) -> HashResult in

            switch response.statusCode
            {
            case 401, 403:
                throw Error.Forbidden
            case 429:
                throw Error.QuotaExceeded
            case 400...499:
                throw Error.BadRequest
            case 500...599:
                throw Error.ServerError
            case 200:
                return try Processor.process(response: response)
            default:
                throw Error.InvalidResponse
            }
        }
    }
}

fileprivate struct Processor
{
    static func process(response: NetworkResponse<Data>) throws -> HashResult
    {
        do
        {
            let readingOptions = JSONSerialization.ReadingOptions()
            guard let responseData = response.response,
                  let json = try JSONSerialization.jsonObject(with: responseData, options: readingOptions) as? [String: Any],
                  let locationAuthHash = json["locationAuthHash"] as? Int32,
                  let locationHash = json["locationHash"] as? Int32,
                  let requestHashes = (json["requestHashes"] as? [UInt64]) else
            {
                throw PokeFarmerHashGenerator.Error.InvalidResponse
            }
            
            return HashResult(locationAuthHash: locationAuthHash,
                              locationHash: locationHash,
                              requestHashes: requestHashes)
        }
        catch
        {
            throw PokeFarmerHashGenerator.Error.InvalidResponse
        }
    }
}
