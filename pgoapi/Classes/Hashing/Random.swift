//
//  Random.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/11/15.
//  Copyright © 2016 MC. All rights reserved.
//

import Darwin
import Foundation

class Random
{
    static func getInt(min: UInt32, range: UInt32) -> UInt32
    {
        return min + arc4random_uniform(range)
    }
    
    static func getDouble(min: Int32, range: Int32) -> Double
    {
        let d = Double(arc4random()) / Double(UInt32.max)
        return Double(min) + d * Double(range)
    }
    
    static func choice<T>(_ choices: [T]) -> T
    {
        assert(choices.count > 0)
        
        let idx = arc4random_uniform(UInt32(choices.count))
        return choices[Int(idx)]
    }
    
    static func randomBytes(length: Int) -> Data
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
    
    // from numpy
    static func triangular(min: Double, max: Double, mode: Double) -> Double
    {
        let base = max - min
        let minbase = mode - min
        let ratio = minbase / base
        let minprod = minbase * base
        let maxprod = (max - mode) * base
        
        let u = getDouble(min: 0, range: 1)
        if u <= ratio
        {
            return min + sqrt(u * minprod)
        }
        else
        {
            return max - sqrt((1.0 - u) * maxprod)
        }
    }
}
