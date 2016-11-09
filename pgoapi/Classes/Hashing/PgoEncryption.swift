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
    public typealias EncryptFunction = (_ input: Data, _ iv: Data) -> Data
    public static var encrypt: EncryptFunction?
}
