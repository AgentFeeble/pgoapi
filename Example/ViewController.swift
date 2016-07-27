//
//  ViewController.swift
//  Example
//
//  Created by Rayman Rosevear on 2016/07/25.
//  Copyright © 2016 MC. All rights reserved.
//

import UIKit
import pgoapi
import Alamofire
import BoltsSwift

class ViewController: UIViewController
{
    private let network: Network = AlamoFireNetwork.defaultFireNetwork()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        Auth(network: network).login("username", password: "password")
        .continueWith(.MainThread)
        {
            (task: Task<AuthToken>) -> () in
            print(task)
        }
    }
}

