//
//  NetworkError.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/28.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

public enum NetworkError: Error
{
    case invalidResponse
    case invalidStatusCode(Int)
    case deserializationError(Error)
}
