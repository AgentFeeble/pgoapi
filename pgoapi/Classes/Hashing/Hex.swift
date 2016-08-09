//
//  Hex.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/08/08.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

enum UnHexlifyError: ErrorType
{
    case NonHexStringProvided
}

/// Ported from the Python binascii module
func unhexlify(string: String) throws -> NSData
{
    let input = string.characters.count % 2 == 0 ? string : "0\(string)"
    let inputScalars = input.unicodeScalars
    
    let output = NSMutableData(capacity: inputScalars.count / 2)!
    
    var inIdx = inputScalars.startIndex
    for _ in 0.stride(to: input.characters.count, by: 2)
    {
        let t = hexInt(forChar: inputScalars[inIdx]); inIdx = inIdx.successor()
        let b = hexInt(forChar: inputScalars[inIdx]); inIdx = inIdx.successor()
        
        guard let top = t, let bot = b else
        {
            throw UnHexlifyError.NonHexStringProvided
        }
        
        let byte = UInt8((top << 4) + bot)
        output.appendBytes([byte], length: 1)
    }
    
    return output
}

private func hexInt(forChar char: UnicodeScalar) -> Int?
{
    let charValue = tolower(Int32(char.value))
    if isdigit(charValue) != 0
    {
        let zero = "0".unicodeScalars
        return Int32(char.value) - Int32(zero[zero.startIndex].value);
    }
    else
    {
        let a = "a".unicodeScalars
        let f = "f".unicodeScalars
        let aValue = Int32(a[a.startIndex].value)
        let fValue = Int32(f[f.startIndex].value)
        
        if charValue >= aValue && charValue <= fValue
        {
            return charValue - aValue + 10;
        }
    }
    return nil
}
