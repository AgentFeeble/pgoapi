//
//  ProtoBufDataConverter.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/29.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation
import ProtocolBuffers

struct ProtoBufDataConverter<T: GeneratedMessage>: DataConverter
{
    typealias OutputType = T
    
    let convertFunc: (data: NSData) throws -> T
    
    func convert(data: NSData) throws -> T
    {
        return try convertFunc(data: data)
    }
}
