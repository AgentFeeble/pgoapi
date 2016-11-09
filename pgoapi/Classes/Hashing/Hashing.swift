//
//  Hashing.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/08/08.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

// These functions were ported from https://github.com/keyphact/pgoapi (Utilities.py). Thanks to them for doing
// all the heavy lifting.

func generateLocation1(ticket authTicket: Data, lat: Double, lng: Double, altitude: Double) -> UInt32
{
    let firstHash = pgo_hash_32((authTicket as NSData).bytes, authTicket.count, 0x1B845238)
    var locationData = (d2h(lat) as NSData).mutableCopy() as! NSMutableData
    locationData += d2h(lng)
    locationData += d2h(altitude)
    
    return pgo_hash_32(locationData.bytes, locationData.length, firstHash)
}

func generateLocation2(lat: Double, lng: Double, altitude: Double) -> UInt32
{
    var locationData = (d2h(lat) as NSData).mutableCopy() as! NSMutableData
    locationData += d2h(lng)
    locationData += d2h(altitude)
    
    return pgo_hash_32(locationData.bytes, locationData.length, 0x1B845238)
}

func generateRequestHash(ticket authTicket: Data, requestData: Data) -> UInt64
{
    let firstHash = pgo_hash_64((authTicket as NSData).bytes, authTicket.count, 0x1B845238)
    return pgo_hash_64((requestData as NSData).bytes, requestData.count, firstHash)
}

func randomBytes(length: Int) -> Data
{
    var data = Data(count: length)
    let result = data.withUnsafeMutableBytes
    {
        bytes in
        SecRandomCopyBytes(kSecRandomDefault, data.count, bytes)
    }
    
    if result != 0
    {
        print("unable to generate random bytes")
    }
    return data
}

private func d2h(_ value: Double) -> Data
{
    assert(Int(OSHostByteOrder()) == OSLittleEndian, "\(#file) assumes little endian, but host is big endian")
    
    let asUInt64 = unsafeBitCast(value, to: UInt64.self)
    let asHex = String(asUInt64, radix: 16)
    
    // Force unwrap, Swift is misbehaving if `asHex` contains non-hex characters
    return try! unhexlify(asHex)
}

private func +=(left: inout NSMutableData, right: Data)
{
    left.append(right)
}
