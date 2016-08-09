//
//  Encrypt.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/08/09.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

func pgoEncrypt(input: NSData, iv: NSData) -> NSData
{
    var outputSize: size_t = 0
    encryptMethod(UnsafePointer<UInt8>(input.bytes), input.length,
                  UnsafePointer<UInt8>(iv.bytes), iv.length, nil, &outputSize)
    
    let output: NSData = NSMutableData(length: outputSize)!
    encryptMethod(UnsafePointer<UInt8>(input.bytes), input.length,
                  UnsafePointer<UInt8>(iv.bytes), iv.length,
                  UnsafeMutablePointer<UInt8>(output.bytes), &outputSize)
    
    let usedOutput = outputSize < output.length ? output.subdataWithRange(NSMakeRange(0, outputSize)) : output
    return usedOutput
}
