//
//  PgoEncryption.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/08/09.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

public struct PgoEncryption
{
    public typealias HashFunction = (_ in: UnsafePointer<UInt8>, _ len: UInt32) -> UInt64
    public typealias EncryptFunction = (_ input: Data, _ iv: UInt32) -> Data
    
    public static var hash: HashFunction?
    public static var encrypt: EncryptFunction?
}
