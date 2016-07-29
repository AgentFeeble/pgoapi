//
//  Decoder.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/29.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

/// This is basically a generic concrete wrapper around the DataConverter protocol
struct Decoder<T, C: DataConverter where C.OutputType == T>
{
    let converter: C
    
    func decode(data: NSData) throws -> T
    {
        return try converter.convert(data)
    }
}
