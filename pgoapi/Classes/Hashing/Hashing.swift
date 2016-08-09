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

func generateLocation1(ticket authTicket: NSData, lat: Double, lng: Double, altitude: Double) -> UInt32
{
    let firstHash = pgo_hash_32(authTicket.bytes, authTicket.length, 0x1B845238)
    var locationData = d2h(lat).mutableCopy() as! NSMutableData
    locationData += d2h(lng)
    locationData += d2h(altitude)
    
    return pgo_hash_32(locationData.bytes, locationData.length, firstHash)
}

func generateLocation2(lat lat: Double, lng: Double, altitude: Double) -> UInt32
{
    var locationData = d2h(lat).mutableCopy() as! NSMutableData
    locationData += d2h(lng)
    locationData += d2h(altitude)
    
    return pgo_hash_32(locationData.bytes, locationData.length, 0x1B845238)
}

func generateRequestHash(ticket authTicket: NSData, requestData: NSData) -> UInt64
{
    let firstHash = pgo_hash_64(authTicket.bytes, authTicket.length, 0x1B845238)
    return pgo_hash_64(requestData.bytes, requestData.length, firstHash)
}

func randomBytes(length length: Int) -> NSData
{
    let data = NSMutableData(length: length)!
    if SecRandomCopyBytes(kSecRandomDefault, length, UnsafeMutablePointer<UInt8>(data.bytes)) != 0
    {
        print("unable to generate random bytes")
    }
    return data
}

private func d2h(value: Double) -> NSData
{
    assert(Int(OSHostByteOrder()) == OSLittleEndian, "\(#file) assumes little endian, but host is big endian")
    
    let asUInt64 = unsafeBitCast(value, UInt64.self)
    let asHex = String(asUInt64, radix: 16)
    
    // Force unwrap, Swift is misbehaving if `asHex` contains non-hex characters
    return try! unhexlify(asHex)
}

private func +=(inout left: NSMutableData, right: NSData)
{
    left.appendData(right)
}
