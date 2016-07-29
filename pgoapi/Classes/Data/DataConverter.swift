//
//  DataConverter.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/29.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

protocol DataConverter
{
    associatedtype OutputType
    func convert(data: NSData) throws -> OutputType
}
