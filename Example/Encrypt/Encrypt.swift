//
//  Encrypt.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/08/09.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

func pgoEncrypt(_ input: Data, iv: UInt32) -> Data
{
    let inputLen = input.count
    return input.withUnsafeBytes
    {
        (input: UnsafePointer<Int8>) in
        
        var output: UnsafeMutablePointer<Int8>? = nil
        let outputSize = encryptMethod(input, inputLen, iv, &output)
        
        return Data(bytesNoCopy: output!, count: Int(outputSize), deallocator: .free)
    }
}
