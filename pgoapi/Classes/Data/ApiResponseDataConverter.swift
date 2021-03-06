//
//  ApiResponseDataConverter.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/29.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation
import ProtocolBuffers

struct ApiResponseDataConverter: DataConverter
{
    typealias OutputType = ApiResponse
    typealias SubResponseConverter = ProtoBufDataConverter<GeneratedMessage>
    
    struct Builder
    {
        private var subResponseConverters: [(ApiResponse.RequestType, SubResponseConverter)] = []
        
        mutating func addSubResponseConverter(_ type: ApiResponse.RequestType, converter: SubResponseConverter)
        {
            subResponseConverters.append((type, converter))
        }
        
        func build() -> ApiResponseDataConverter
        {
            return ApiResponseDataConverter(subResponseConverters: subResponseConverters)
        }
    }
    
    private let subResponseConverters: [(ApiResponse.RequestType, SubResponseConverter)]
    
    func convert(_ data: Data) throws -> ApiResponse
    {
        let response = try Pogoprotos.Networking.Envelopes.ResponseEnvelope.parseFrom(data: data)
        let subresponses = try parseSubResponses(response)
        return ApiResponse(response: response, subresponses: subresponses)
    }
    
    private func parseSubResponses(_ response: Pogoprotos.Networking.Envelopes.ResponseEnvelope) throws -> [ApiResponse.RequestType : GeneratedMessage]
    {
        let subresponseCount = min(subResponseConverters.count, response.returns.count)
        var subresponses: [ApiResponse.RequestType : GeneratedMessage] = [:]
        for (idx, subresponseData) in response.returns[ 0..<subresponseCount ].enumerated()
        {
            let (requestType, converter) = subResponseConverters[idx]
            subresponses[requestType] = try converter.convert(subresponseData)
        }
        return subresponses
    }
}
