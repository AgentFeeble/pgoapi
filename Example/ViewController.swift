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

typealias MapPokemon = Pogoprotos.Map.Pokemon.MapPokemon
typealias GetMapObjectsResponse = Pogoprotos.Networking.Responses.GetMapObjectsResponse
typealias EncounterResponse = Pogoprotos.Networking.Responses.EncounterResponse

class ViewController: UIViewController
{
    private let network: Network = AlamoFireNetwork.defaultFireNetwork()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        print("Logging in")
        
        var api: PgoApi!
        
        let network = self.network
//        let hasher = NativeHashGenerator(hashFunction: compute_hash)
        let hasher = PokeFarmerHashGenerator(network: network, apiKey: "Hash Server API Key")
        
        AuthRequest(network: network).login("spamflip", password: "hoboman")
        .continueOnSuccessWith(.mainThread)
        {
            result in
            
            let config = PgoApiConfig(network: network, hasher: hasher)
            return PgoApi(config: config, authToken: result)
        }
        .continueOnSuccessWithTask(.mainThread)
        {
            (responseApi: PgoApi) -> Task<ApiResponse> in
            
            print("Getting map objects")
            api = responseApi
            
            let location = Location(latitude: 40.783027, longitude: -73.965130, altitude: 10.1)
            return api.builder(location).getMapObjects().execute()
        }
        .continueOnSuccessWith(.mainThread)
        {
            (response: ApiResponse) -> MapPokemon? in
            
            let mapObjects = response.subresponses[.getMapObjects] as? GetMapObjectsResponse
            print(PokeHelper.getMapObjectsDescription(mapObjects: mapObjects))
            
            return PokeHelper.getFirstCatchablePokemon(mapObjects: mapObjects)
        }
        .continueOnSuccessWithTask(.mainThread)
        {
            (pokemon: MapPokemon?) -> Task<()> in
            
            if let pokemon = pokemon
            {
                print("Found catchable pokemon \(pokemon.pokemonId.toString()). Beginning encounter")
                return PokeHelper.encounterPokemon(api: api, pokemon: pokemon)
                .continueOnSuccessWith(.mainThread)
                {
                    (response: ApiResponse) -> () in
                    let encounterResponse = response.subresponses[.encounter] as? EncounterResponse
                    print(PokeHelper.getEncounterResponseDescription(response: encounterResponse))
                    return ()
                }
            }
            
            print("No catchable pokemon found")
            return Task(())
        }
        .continueWith(.mainThread)
        {
            (task: Task<()>) -> () in
            
            print(task)
            print()
        }
    }
}

struct PokeHelper
{
    static func getMapObjectsDescription(mapObjects: GetMapObjectsResponse?) -> String
    {
        guard let mapObjects = mapObjects else
        {
            return "(null) map objects instance"
        }
        
        let cells = mapObjects.mapCells.count
        var catchable = 0
        var nearby = 0
        var wild = 0
        var forts = 0
        var spawns = 0
        
        for mapCell in mapObjects.mapCells
        {
            catchable += mapCell.catchablePokemons.count
            nearby += mapCell.nearbyPokemons.count
            wild += mapCell.wildPokemons.count
            forts += mapCell.forts.count
            spawns += mapCell.spawnPoints.count
        }
        
        return "map objects:\n\tcells: \(cells)\n\tspawns: \(spawns)\n\tforts: \(forts)\n\tcatchable: \(catchable)\n\tnearby: \(nearby)\n\twild: \(wild)\n"
    }
    
    static func getEncounterResponseDescription(response: EncounterResponse?) -> String
    {
        guard let response = response else
        {
            return "(null) encounter response"
        }
        
        return "Encounter response dump: \n\(String(describing: response))"
    }
    
    static func getFirstCatchablePokemon(mapObjects: GetMapObjectsResponse?) -> MapPokemon?
    {
        guard let mapObjects = mapObjects else
        {
            return nil
        }
        
        for mapCell in mapObjects.mapCells.reversed()
        {
            if let pokemon = mapCell.catchablePokemons.first
            {
                return pokemon
            }
        }
        return nil
    }
    
    static func encounterPokemon(api: PgoApi, pokemon: MapPokemon) -> Task<ApiResponse>
    {
        let location = Location(latitude: pokemon.latitude + 0.00004, longitude: pokemon.longitude + 0.00004)
        return api.builder(location).encounterPokemon(encounterId: pokemon.encounterId, spawnPointId: pokemon.spawnPointId).execute()
    }
}

