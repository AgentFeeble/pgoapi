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
        
        let network = self.network
        Auth(network: network).login("username", password: "password")
        .continueOnSuccessWith(.MainThread)
        {
            result in
            return PgoApi(network: network, authToken: result)
        }
        .continueOnSuccessWithTask(.MainThread)
        {
            api -> Task<ApiResponse> in
            let location = Location(latitude: 40.783027, longitude: -73.965130, altitude: 10.1)
            return api.builder(location).getMapObjects().execute()
        }
        .continueOnSuccessWith(.MainThread)
        {
            response in
            let mapObjects = response.subresponses[.GetMapObjects] as? pgoapi.Pogoprotos.Networking.Responses.GetMapObjectsResponse
            print(mapObjects)
            return ()
        }
        .continueWith(.MainThread)
        {
            (task: Task<()>) -> () in
            print(task)
            print()
        }
    }
}

