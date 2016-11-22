//
//  Decoder.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/29.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

/// This is basically a generic concrete wrapper around the DataConverter protocol
struct Decoder<T, Converter: DataConverter> where Converter.OutputType == T
{
    let converter: Converter
    
    func decode(_ data: Data) throws -> T
    {
        return try converter.convert(data)
    }
}
