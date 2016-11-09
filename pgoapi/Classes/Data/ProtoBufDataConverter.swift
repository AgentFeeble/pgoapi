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
    
    let convertFunc: (_ data: Data) throws -> T
    
    func convert(_ data: Data) throws -> T
    {
        return try convertFunc(data)
    }
}
