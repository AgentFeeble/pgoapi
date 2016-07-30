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
        .continueOnSuccessWithTask(.MainThread)
        {
            result in
            return PgoApi(network: network, authToken: result).login()
        }
        .continueOnSuccessWithTask(.MainThread)
        {
            (api, response) -> Task<ApiResponse> in
            let location = Location(latitude: -26.147102, longitude: 28.139760)
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

