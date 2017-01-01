//
//  NativeHashGenerator.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/11/11.
//  Copyright © 2016 MC. All rights reserved.
//

import BoltsSwift
import Foundation

private let kHashSeed: UInt32 = 0x46E945F8

public struct NativeHashGenerator: HashGenerator
{
    public typealias HashFunction = (_ in: UnsafePointer<UInt8>, _ len: UInt32) -> UInt64
    public let hashFunction: HashFunction
    
    public init(hashFunction: @escaping HashFunction)
    {
        self.hashFunction = hashFunction
    }
    
    public func generateHash(timestamp: UInt64,
                             latitude: Double,
                             longitude: Double,
                             altitude: Double,
                             authTicket: Data,
                             sessionData: Data,
                             requests: [Data]) -> Task<HashResult>
    {
        let locationAuthHash = generateLocationHashBySeed(authTicket: authTicket, lat: latitude, lng: longitude, acc: altitude)
        let locationHash = generateLocationHash(lat: latitude, lng: longitude, acc: altitude);
        let requestHashes = requests.map( { generateRequestHash(authTicket: authTicket, request: $0) } );
        
        return Task(HashResult(locationAuthHash: locationAuthHash, locationHash: locationHash, requestHashes: requestHashes))
    }
    
    func generateLocationHashBySeed(authTicket: Data, lat: Double, lng: Double, acc: Double) -> Int32
    {
        let first = hash32(buffer: authTicket, seed: kHashSeed)
        let locationData = d2h(lat) + d2h(lng) + d2h(acc)
        let hash = hash32(buffer: locationData, seed: first)
        
        return Int32(bitPattern: hash)
    }
    
    func generateLocationHash(lat: Double, lng: Double, acc: Double) -> Int32
    {
        let locationData = d2h(lat) + d2h(lng) + d2h(acc)
        let hash = hash32(buffer: locationData, seed: kHashSeed)
        
        return Int32(bitPattern: hash)
    }
    
    func generateRequestHash(authTicket: Data, request: Data) -> UInt64
    {
        let first = hash64salt32(buffer: authTicket, seed: kHashSeed)
        let hash = hash64salt64(buffer: request, seed: first)
        
        return hash
    }
    
    private func hash64salt32(buffer: Data, seed: UInt32) -> UInt64
    {
        let seeded = try! Struct.pack(values: [seed], format: ">I") + buffer
        return computeHash(buffer: seeded)
    }
    
    private func hash64salt64(buffer: Data, seed: UInt64) -> UInt64
    {
        let seeded = try! Struct.pack(values: [seed], format: ">Q") + buffer
        return computeHash(buffer: seeded)
    }
    
    private func hash32(buffer: Data, seed: UInt32) -> UInt32
    {
        let prefix = try! Struct.pack(values: [seed], format: ">I")
        let hash64 = computeHash(buffer: prefix + buffer)
        let signedHash64 = Int64(bitPattern: hash64)
        
        return UInt32(truncatingBitPattern: signedHash64) ^ UInt32(truncatingBitPattern: signedHash64 >> Int64(32))
    }
    
    private func computeHash(buffer: Data) -> UInt64
    {
        return buffer.withUnsafeBytes
            {
                (buf: UnsafePointer<UInt8>) in
                return hashFunction(buf, UInt32(buffer.count))
        }
    }
    
    private func d2h(_ value: Double) -> Data
    {
        assert(Int(OSHostByteOrder()) == OSLittleEndian, "\(#file) assumes little endian, but host is big endian")
        
        let asUInt64 = unsafeBitCast(value, to: UInt64.self)
        let asHex = String(asUInt64, radix: 16)
        
        // Force unwrap, Swift is misbehaving if `asHex` contains non-hex characters
        return try! unhexlify(asHex)
    }
}

