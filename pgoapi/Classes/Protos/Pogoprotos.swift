//
//  Pogoprotos.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/27.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation
import ProtocolBuffers

/**
 * This struct declaration is needed as a fix for issue https://github.com/alexeyxo/protobuf-swift/issues/150.
 * It involved manually editing the generated files, which is less than desirable, especially if the classes
 * need to be regenerated.
 */
public struct Pogoprotos
{
    public struct Data
    {
        public struct Badge {}
        public struct Battle {}
        public struct Capture {}
        public struct Gym {}
        public struct Logs {}
        public struct Player {}
        public struct Quests {}
    }
    
    public struct Enums {}
    
    public struct Inventory
    {
        public struct Item {}
    }
    
    public struct Map
    {
        public struct Fort {}
        public struct Pokemon {}
    }
    
    public struct Networking
    {
        public struct Envelopes {}
        public struct Responses {}
        
        public struct Platform
        {
            public struct Requests {}
            public struct Responses {}
        }
        
        public struct Requests
        {
            public struct Messages {}
        }
    }
    
    public struct Settings
    {
        public struct Master
        {
            public struct Item {}
            public struct Pokemon {}
            public struct Quest {}
        }
    }
}
