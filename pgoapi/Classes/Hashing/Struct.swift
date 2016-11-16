//
//  Struct.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/11/15.
//  Copyright © 2016 MC. All rights reserved.
//
//  This is a modified version of https://github.com/MagerValp/MVPCStruct, compatible with Swift 3
//

import Foundation

//      BYTE ORDER      SIZE            ALIGNMENT
//  @   native          native          native
//  =   native          standard        none
//  <   little-endian   standard        none
//  >   big-endian      standard        none
//  !   network (BE)    standard        none


//      FORMAT  C TYPE                  SWIFT TYPE              SIZE
//      x       pad byte                no value
//      c       char                    String of length 1      1
//      b       signed char             Int                     1
//      B       unsigned char           UInt                    1
//      ?       _Bool                   Bool                    1
//      h       short                   Int                     2
//      H       unsigned short          UInt                    2
//      i       int                     Int                     4
//      I       unsigned int            UInt                    4
//      l       long                    Int                     4
//      L       unsigned long           UInt                    4
//      q       long long               Int                     8
//      Q       unsigned long long      UInt                    8
//      f       float                   Float                   4
//      d       double                  Double                  8
//      s       char[]                  String
//      p       char[]                  String
//      P       void *                  UInt                    4/8
//
//      Floats and doubles are packed with IEEE 754 binary32 or binary64 format.


// Split a large integer into bytes.
private extension Int
{
    func splitBytes(_ endianness: Struct.Endianness, size: Int) -> [UInt8]
    {
        var bytes: [UInt8] = []
        var shift: Int
        var step: Int
        if endianness == .little
        {
            shift = 0
            step = 8
        }
        else
        {
            shift = (size - 1) * 8
            step = -8
        }
        for _ in 0 ..< size
        {
            bytes.append(UInt8((self >> shift) & 0xff))
            shift += step
        }
        return bytes
    }
}

private extension UInt
{
    func splitBytes(_ endianness: Struct.Endianness, size: Int) -> [UInt8]
    {
        var bytes: [UInt8] = []
        var shift: Int
        var step: Int
        if endianness == .little
        {
            shift = 0
            step = 8
        }
        else
        {
            shift = Int((size - 1) * 8)
            step = -8
        }
        for _ in 0 ..< size
        {
            bytes.append(UInt8((self >> UInt(shift)) & 0xff))
            shift = shift + step
        }
        return bytes
    }
}


class Struct: NSObject
{
    enum StructError: Error
    {
        case parsing
        case packing(String)
        case unpacking(String)
    }
    
    enum Endianness
    {
        case little
        case big
    }
    
    // Packing format strings are parsed to a stream of ops.
    enum Ops
    {
        // Stop packing.
        case stop
        
        // Control endianness.
        case setNativeEndian
        case setLittleEndian
        case setBigEndian
        
        // Control alignment.
        case setAlign
        case unsetAlign
        
        // Pad bytes.
        case skipByte
        
        // Packed values.
        case packChar
        case packInt8
        case packUInt8
        case packBool
        case packInt16
        case packUInt16
        case packInt32
        case packUInt32
        case packInt64
        case packUInt64
        case packFloat
        case packDouble
        case packCString
        case packPString
        case packPointer
    }
    
    private static let bytesForValue = [
        Ops.skipByte:       1,
        Ops.packChar:       1,
        Ops.packInt8:       1,
        Ops.packUInt8:      1,
        Ops.packBool:       1,
        Ops.packInt16:      2,
        Ops.packUInt16:     2,
        Ops.packInt32:      4,
        Ops.packUInt32:     4,
        Ops.packInt64:      8,
        Ops.packUInt64:     8,
        Ops.packFloat:      4,
        Ops.packDouble:     8,
        Ops.packPointer:    MemoryLayout<UnsafeRawPointer>.size,
    ]
    
    private static let PAD_BYTE = UInt8(0)
    
    class var platformEndianness: Endianness { return (Int(OSHostByteOrder()) == OSLittleEndian) ? .little : .big }
    
    // MARK: Unpacking
    
    class func unpack(_ data: Data, format: String) throws -> [Any]?
    {
        let opStream = try self.parse(format: format)
        return try self.unpack(data: data, opStream: opStream)
    }
    
    class func unpack(data: Data, opStream: [Ops]) throws -> [Any]?
    {
        var values: [Any] = []
        var index = 0
        var alignment = true
        var endianness = self.platformEndianness
        
        // If alignment is requested, skip pad bytes until alignment is
        // satisfied.
        func skipAlignment(size: Int)
        {
            if alignment
            {
                let mask = size - 1
                while (index & mask) != 0
                {
                    index += 1
                }
            }
        }
        
        // Read UInt8 values from data.
        func readBytes(count: Int) -> [UInt8]?
        {
            var bytes: [UInt8] = []
            let end = index + count
            if end > data.count
            {
                return nil
            }
            
            let subdata = data.subdata(in: index..<end)
            subdata.forEach { bytes.append($0) }
            
            index += count
            return bytes
        }
        
        // Create integer from bytes.
        func intFromBytes(bytes: [UInt8]) -> Int
        {
            var i: Int = 0
            for byte in endianness == .little ? bytes.reversed() : bytes
            {
                i <<= 8
                i |= Int(byte)
            }
            return i
        }
        func uintFromBytes(bytes: [UInt8]) -> UInt
        {
            var i: UInt = 0
            for byte in endianness == .little ? bytes.reversed() : bytes
            {
                i <<= 8
                i |= UInt(byte)
            }
            return i
        }
        
        for op in opStream
        {
            // First check ops that don't consume data.
            switch op
            {
                
            case .stop:
                return values
                
            case .setNativeEndian:
                endianness = self.platformEndianness
            case .setLittleEndian:
                endianness = .little
            case .setBigEndian:
                endianness = .big
                
            case .setAlign:
                alignment = true
            case .unsetAlign:
                alignment = false
                
            case .packCString, .packPString:
                assert(false, "cstring/pstring unimplemented")
                
            case .skipByte:
                if readBytes(count: 1) != nil
                {
                    // Discard.
                }
                else
                {
                    throw StructError.unpacking("not enough data for format")
                }
            default:
                let bytesToUnpack = bytesForValue[op]!
                if let bytes = readBytes(count: bytesToUnpack)
                {
                    switch op
                    {
                    case .skipByte:
                        break
                    
                    case .packChar:
                        values.append(NSString(format: "%c", bytes[0]))
                        
                    case .packInt8:
                        values.append(Int(bytes[0]))
                        
                    case .packUInt8:
                        values.append(UInt(bytes[0]))
                        
                    case .packBool:
                        if bytes[0] == UInt8(0)
                        {
                            values.append(false)
                        }
                        else
                        {
                            values.append(true)
                        }
                        
                    case .packInt16, .packInt32, .packInt64:
                        values.append(intFromBytes(bytes: bytes))
                        
                    case .packUInt16, .packUInt32, .packUInt64, .packPointer:
                        values.append(uintFromBytes(bytes: bytes))
                        
                    case .packFloat, .packDouble:
                        assert(false, "float/double unimplemented")
                        
                    case .packCString, .packPString:
                        assert(false, "cstring/pstring unimplemented")
                        
                    default:
                        assert(false, "bad op in stream")
                    }
                    
                }
                else
                {
                    throw StructError.unpacking("not enough data for format")
                }
            }
            
        }
        
        return values
    }
    
    
    // MARK: Packing
    
    class func pack(values: [Any], format: String) throws -> Data
    {
        let opStream = try parse(format: format)
        return try self.pack(values: values, opStream: opStream)
    }
    
    class func pack(values: [Any], opStream: [Ops]) throws -> Data
    {
        var bytes: [UInt8] = []
        var index = 0
        var alignment = true
        var endianness = self.platformEndianness
        
        // If alignment is requested, emit pad bytes until alignment is
        // satisfied.
        func padAlignment(_ size: Int)
        {
            if alignment
            {
                let mask = size - 1
                while (bytes.count & mask) != 0
                {
                    bytes.append(PAD_BYTE)
                }
            }
        }
        
        for op in opStream
        {
            // First check ops that don't consume values.
            switch op
            {
            case .stop:
                if index != values.count
                {
                    throw StructError.packing("expected \(index) items for packing, got \(values.count)")
                }
                else
                {
                    return Data(bytes: bytes)
                }
                
            case .setNativeEndian:
                endianness = self.platformEndianness
            case .setLittleEndian:
                endianness = .little
            case .setBigEndian:
                endianness = .big
                
            case .setAlign:
                alignment = true
            case .unsetAlign:
                alignment = false
                
            case .skipByte:
                bytes.append(PAD_BYTE)
                
            default:
                // No control op found so pop the next value.
                if index >= values.count
                {
                    throw StructError.packing("expected at least \(index) items for packing, got \(values.count)")
                }
                let rawValue: Any = values[index]
                index += 1
                
                switch op
                {
                case .packChar:
                    if let str = rawValue as? String
                    {
                        let codePoint = str.utf16[str.utf16.startIndex]
                        if codePoint < 128
                        {
                            bytes.append(UInt8(codePoint))
                        }
                        else
                        {
                            throw StructError.packing("char format requires String of length 1")
                        }
                    }
                    else
                    {
                        throw StructError.packing("char format requires String of length 1")
                    }
                    
                case .packInt8:
                    if let value = (rawValue as? NSNumber)?.intValue
                    {
                        if value >= -0x80 && value <= 0x7f
                        {
                            bytes.append(UInt8(value & 0xff))
                        }
                        else
                        {
                            throw StructError.packing("value outside valid range of Int8")
                        }
                    }
                    else
                    {
                        throw StructError.packing("cannot convert argument to Int")
                    }
                    
                case .packUInt8:
                    if let value = (rawValue as? NSNumber)?.uintValue
                    {
                        if value > 0xff
                        {
                            throw StructError.packing("value outside valid range of UInt8")
                        }
                        else
                        {
                            bytes.append(UInt8(value))
                        }
                    }
                    else
                    {
                        throw StructError.packing("cannot convert argument to UInt")
                    }
                    
                case .packBool:
                    if let value = (rawValue as? NSNumber)?.boolValue
                    {
                        if value
                        {
                            bytes.append(UInt8(1))
                        }
                        else
                        {
                            bytes.append(UInt8(0))
                        }
                    }
                    else
                    {
                        throw StructError.packing("cannot convert argument to Bool")
                    }
                    
                case .packInt16:
                    if let value = (rawValue as? NSNumber)?.intValue
                    {
                        if value >= -0x8000 && value <= 0x7fff
                        {
                            padAlignment(2)
                            bytes += value.splitBytes(endianness, size: 2)
                        }
                        else
                        {
                            throw StructError.packing("value outside valid range of Int16")
                        }
                    }
                    else
                    {
                        throw StructError.packing("cannot convert argument to Int")
                    }
                    
                case .packUInt16:
                    if let value = (rawValue as? NSNumber)?.uintValue
                    {
                        if value > 0xffff
                        {
                            throw StructError.packing("value outside valid range of UInt16")
                        }
                        else
                        {
                            padAlignment(2)
                            bytes += value.splitBytes(endianness, size: 2)
                        }
                    }
                    else
                    {
                        throw StructError.packing("cannot convert argument to UInt")
                    }
                    
                case .packInt32:
                    if let value = (rawValue as? NSNumber)?.intValue
                    {
                        if value >= -0x80000000 && value <= 0x7fffffff
                        {
                            padAlignment(4)
                            bytes += value.splitBytes(endianness, size: 4)
                        }
                        else
                        {
                            throw StructError.packing("value outside valid range of Int32")
                        }
                    }
                    else
                    {
                        throw StructError.packing("cannot convert argument to Int")
                    }
                    
                case .packUInt32:
                    if let value = (rawValue as? NSNumber)?.uintValue
                    {
                        if value > 0xffffffff
                        {
                            throw StructError.packing("value outside valid range of UInt32")
                        }
                        else
                        {
                            padAlignment(4)
                            bytes += value.splitBytes(endianness, size: 4)
                        }
                    }
                    else
                    {
                        throw StructError.packing("cannot convert argument to UInt")
                    }
                    
                case .packInt64:
                    if let value = (rawValue as? NSNumber)?.intValue
                    {
                        padAlignment(8)
                        bytes += value.splitBytes(endianness, size: 8)
                    }
                    else
                    {
                        throw StructError.packing("cannot convert argument to Int")
                    }
                    
                case .packUInt64:
                    if let value = (rawValue as? NSNumber)?.uintValue
                    {
                        padAlignment(8)
                        bytes += value.splitBytes(endianness, size: 8)
                    }
                    else
                    {
                        throw StructError.packing("cannot convert argument to UInt")
                    }
                    
                case .packFloat, .packDouble:
                    assert(false, "float/double unimplemented")
                    
                case .packCString, .packPString:
                    assert(false, "cstring/pstring unimplemented")
                    
                case .packPointer:
                    if let value = (rawValue as? NSNumber)?.uintValue
                    {
                        padAlignment(MemoryLayout<UnsafeRawPointer>.size)
                        bytes += value.splitBytes(endianness, size: MemoryLayout<UnsafeRawPointer>.size)
                    }
                    else
                    {
                        throw StructError.packing("cannot convert argument to UInt")
                    }
                    
                default:
                    assert(false, "bad op in stream")
                }
                
            }
            
        }
        
        // This is actually never reached, we exit from .stop
        return Data(bytes: bytes)
    }
    
    // MARK: Parsing
    
    class func parse(format: String) throws -> [Ops]
    {
        var rep = 0
        var opStream: [Ops] = []
        
        for c in format.characters
        {
            // First test if the format string contains an integer. In that case
            // we feed it into the repeat counter and go to the next character.
            if let value = Int(String(c))
            {
                rep = rep * 10 + value
                continue
            }
            // The next step depends on if we've accumulated a repeat count.
            if rep == 0
            {
                // With a repeat count of 0 we check for control characters.
                switch c
                {
                    // Control endianness.
                case "@":
                    opStream.append(.setNativeEndian)
                    opStream.append(.setAlign)
                case "=":
                    opStream.append(.setNativeEndian)
                    opStream.append(.unsetAlign)
                case "<":
                    opStream.append(.setLittleEndian)
                    opStream.append(.unsetAlign)
                case ">", "!":
                    opStream.append(.setBigEndian)
                    opStream.append(.unsetAlign)
                    
                case " ":
                    // Whitespace is allowed between formats.
                    break
                    
                default:
                    // No control character found so set the repeat count to 1
                    // and evaluate format characters.
                    rep = 1
                }
            }
            
            // If we have a repeat count we expect a format character.
            if rep > 0
            {
                // Add one op for each repeat count.
                for _ in 0 ..< rep
                {
                    switch c
                    {
                    case "x":       opStream.append(.skipByte)
                    case "c":       opStream.append(.packChar)
                    case "?":       opStream.append(.packBool)
                    case "b":       opStream.append(.packInt8)
                    case "B":       opStream.append(.packUInt8)
                    case "h":       opStream.append(.packInt16)
                    case "H":       opStream.append(.packUInt16)
                    case "i", "l":  opStream.append(.packInt32)
                    case "I", "L":  opStream.append(.packUInt32)
                    case "q":       opStream.append(.packInt64)
                    case "Q":       opStream.append(.packUInt64)
                    case "f":       opStream.append(.packFloat)
                    case "d":       opStream.append(.packDouble)
                    case "s":       opStream.append(.packCString)
                    case "p":       opStream.append(.packPString)
                    case "P":       opStream.append(.packPointer)
                    default:
                        throw StructError.parsing
                    }
                }
            }
            // Reset the repeat counter.
            rep = 0
        }
        opStream.append(.stop)
        return opStream
    }
}

