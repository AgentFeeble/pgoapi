//
//  Auth.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/25.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation
import BoltsSwift

public class Auth
{
    public enum AuthError: ErrorType
    {
        case InvalidResponse
        case ClientError(String)
    }
    
    private let network: Network
    
    public init(network: Network)
    {
        self.network = network
    }
    
    public func login(username: String, password: String) -> Task<AuthToken>
    {
        // Note: self is captured strongly to keep a strong reference to self
        // during the API calls
        network.setUserAgent("niantic")
        return network.getJSON(EndPoint.LoginInfo)
        .continueOnSuccessWithTask(network.processingExecutor, continuation:
        {
            (response: NetworkResponse<AnyObject>) -> Task<String> in
            
            // Note strong capture to keep self alive during request
            return try self.getTicket(jsonResponse: response.response, username: username, password: password)
        })
        .continueOnSuccessWithTask(network.processingExecutor, continuation:
        {
            (ticket: String) -> Task<AuthToken> in
            return try self.loginViaOauth(ticket: ticket)
        })
    }

    private func getTicket(jsonResponse response: AnyObject?, username: String, password: String) throws -> Task<String>
    {
        guard let lt = response?["lt"] as? String,
        let execution = response?["execution"] as? String else
        {
            throw AuthError.InvalidResponse
        }
        
        let parameters = [
            "lt": lt,
            "execution": execution,
            "_eventId": "submit",
            "username": username,
            "password": password
        ]
        
        return network.postData(EndPoint.LoginInfo, params: parameters)
        .continueOnSuccessWith(network.processingExecutor, continuation:
        {
            (response: NetworkResponse<NSData>) -> String in
            
            guard let location = response.responseHeaders?["Location"] as? String,
            let ticketRange = location.rangeOfString("?ticket=") else
            {
                throw self.getError(forInvalidTicketResponse: response)
            }
            
            return String(location.characters.suffixFrom(ticketRange.endIndex))
        })
    }
    
    private func loginViaOauth(ticket ticket: String) throws -> Task<AuthToken>
    {
        if ticket.characters.count == 0
        {
            throw AuthError.InvalidResponse
        }
        
        let parameters = [
            "client_id": "mobile-app_pokemon-go",
            "redirect_uri": "https://www.nianticlabs.com/pokemongo/error",
            "client_secret": "w8ScCUXJQc6kXKw8FiOhd8Fixzht18Dq3PEVkUCP5ZPxtgyWsbTvWHFLm2wNY0JR",
            "grant_type": "refresh_token",
            "code": ticket
        ]
        
        return network.postString(EndPoint.LoginOAuth, params: parameters)
        .continueOnSuccessWith(network.processingExecutor, continuation:
        {
            (response: NetworkResponse<String>) -> AuthToken in
            
            guard let value = response.response,
            let regex = try? NSRegularExpression(pattern: "access_token=([A-Za-z0-9\\-.]+)&expires=([0-9]+)", options: []) else
            {
                throw AuthError.InvalidResponse
            }
            
            let matches = regex.matchesInString(value, options: [], range: NSRange(location: 0, length: value.utf16.count))
            
            // Extract the access_token
            guard matches.count > 0 && matches[0].numberOfRanges >= 3,
            let tokenRange = matches[0].rangeAtIndex(1).rangeForString(value) else
            {
                throw AuthError.InvalidResponse
            }
            
            let token = value.substringWithRange(tokenRange)
            
            // Extract the expiry date
            guard let expiryRange = matches[0].rangeAtIndex(2).rangeForString(value) else
            {
                throw AuthError.InvalidResponse
            }
            
            let date = self.getDate(fromResponse: response)
            let expiryString = value.substringWithRange(expiryRange)
            guard let expiryTime = Int(expiryString) else
            {
                throw AuthError.InvalidResponse
            }
            
            let expiryDate = date.dateByAddingTimeInterval(NSTimeInterval(expiryTime))
            return AuthToken(token: token, expiry: expiryDate)
        })
    }
    
    private func getDate<T>(fromResponse response: NetworkResponse<T>) -> NSDate
    {
        let formatter = NSDateFormatter()
        
        if let dateString = response.responseHeaders?["Date"] as? String,
        let date = formatter.dateFromString(dateString)
        {
            return date
        }
        
        return NSDate()
    }
    
    private func getError(forInvalidTicketResponse response: NetworkResponse<NSData>) -> AuthError
    {
        if let responseData = response.response,
        let json = try? NSJSONSerialization.JSONObjectWithData(responseData, options: NSJSONReadingOptions()),
        let errors = json["errors"] as? [String],
        let error = errors.first
        {
            return AuthError.ClientError(error)
        }
        
        return AuthError.InvalidResponse
    }
}
