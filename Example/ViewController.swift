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
        AuthRequest(network: network).login("username", password: "password")
        .continueOnSuccessWith(.mainThread)
        {
            result in
            return PgoApi(network: network, authToken: result)
        }
        .continueOnSuccessWithTask(.mainThread)
        {
            api -> Task<ApiResponse> in
            let location = Location(latitude: 40.783027, longitude: -73.965130, altitude: 10.1)
            return api.builder(location).getMapObjects().execute()
        }
        .continueOnSuccessWith(.mainThread)
        {
            response in
            let mapObjects = response.subresponses[.getMapObjects] as? pgoapi.Pogoprotos.Networking.Responses.GetMapObjectsResponse
            print(mapObjects as Any)
            return ()
        }
        .continueWith(.mainThread)
        {
            (task: Task<()>) -> () in
            print(task)
            print()
        }
    }
}

