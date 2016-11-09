//
//  NSRange+pgoapi.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/27.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

extension NSRange {
    func rangeForString(_ str: String) -> Range<String.Index>?
    {
        guard location != NSNotFound else { return nil }
        return str.characters.index(str.startIndex, offsetBy: location) ..< str.characters.index(str.startIndex, offsetBy: location + length)
    }
}
