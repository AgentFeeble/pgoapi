//
//  Encrypt.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/08/09.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

func pgoEncrypt(_ input: Data, iv: Data) -> Data
{
    var outputSize: size_t = 0
    encryptMethod((input as NSData).bytes.bindMemory(to: UInt8.self, capacity: input.count), input.count,
                  (iv as NSData).bytes.bindMemory(to: UInt8.self, capacity: iv.count), iv.count, nil, &outputSize)
    
    let output: Data = NSMutableData(length: outputSize)! as Data
    encryptMethod((input as NSData).bytes.bindMemory(to: UInt8.self, capacity: input.count), input.count,
                  (iv as NSData).bytes.bindMemory(to: UInt8.self, capacity: iv.count), iv.count,
                  UnsafeMutablePointer<UInt8>(mutating: (output as NSData).bytes.bindMemory(to: UInt8.self, capacity: output.count)), &outputSize)
    
    let range = Range<Int>(uncheckedBounds: (lower: 0, upper: outputSize))
    let usedOutput = outputSize < output.count ? output.subdata(in: range) : output
    return usedOutput
}
