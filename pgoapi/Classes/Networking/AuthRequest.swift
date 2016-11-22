//
//  AuthRequest.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/07/25.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation
import BoltsSwift

private class AuthID: Synchronizable
{
    private var id: Int = 0
    let synchronizationLock: Lockable = SpinLock()
    
    private static let globalAuthId = AuthID()

    static func newAuthId() -> Int
    {
        return globalAuthId.newId()
    }
    
    private func newId() -> Int
    {
        return sync
        {
            id += 1
            return id
        }
    }
}

public class AuthRequest
{
    public enum AuthError: Error
    {
        case invalidResponse
        case clientError(String)
    }
    
    private let network: Network
    private let sessionId = "Auth Session \(AuthID.newAuthId())"
    
    public init(network: Network)
    {
        self.network = network
    }
    
    public func login(_ username: String, password: String) -> Task<AuthToken>
    {
        // Note: self is captured strongly to keep a strong reference to self
        // during the API calls
        
        let sessionId = self.sessionId
        let args = RequestArgs(sessionId: sessionId)
        return network.getJSON(EndPoint.LoginInfo, args: args)
        .continueOnSuccessWithTask(network.processingExecutor, continuation:
        {
            (response: NetworkResponse<Any>) in
            
            // Note strong capture to keep self alive during request
            return try self.getTicket(response: response, username: username, password: password)
        })
        .continueOnSuccessWithTask(network.processingExecutor, continuation:
        {
            (ticket: String) -> Task<AuthToken> in
            return try self.loginViaOauth(ticket: ticket)
        })
        .continueWithTask(continuation:
        {
            [weak self] task in
            self?.network.resetSessionWithID(sessionID: sessionId)
            return task
        })
    }

    private func getTicket(response: NetworkResponse<Any>, username: String, password: String) throws -> Task<String>
    {
        
        guard let json = response.response as? NSDictionary,
        let lt = json["lt"] as? String,
        let execution = json["execution"] as? String else
        {
            throw AuthError.invalidResponse
        }
        
        let parameters: [String: Any] = [
            "lt": lt,
            "execution": execution,
            "_eventId": "submit",
            "username": username,
            "password": password
        ]
        
        let args = RequestArgs(params: parameters, sessionId: sessionId)
        return network.postData(EndPoint.LoginInfo, args: args)
        .continueOnSuccessWith(network.processingExecutor, continuation:
        {
            (response: NetworkResponse<Data>) -> String in
            
            guard let location = response.responseHeaders?["Location"],
                  let ticketRange = location.range(of: "?ticket=") else
            {
                throw self.getError(forInvalidTicketResponse: response)
            }
            
            return String(location.characters.suffix(from: ticketRange.upperBound))
        })
    }
    
    private func loginViaOauth(ticket: String) throws -> Task<AuthToken>
    {
        if ticket.characters.count == 0
        {
            throw AuthError.invalidResponse
        }
        
        let parameters = [
            "client_id": "mobile-app_pokemon-go",
            "redirect_uri": "https://www.nianticlabs.com/pokemongo/error",
            "client_secret": "w8ScCUXJQc6kXKw8FiOhd8Fixzht18Dq3PEVkUCP5ZPxtgyWsbTvWHFLm2wNY0JR",
            "grant_type": "refresh_token",
            "code": ticket
        ]
        
        return network.postString(EndPoint.LoginOAuth, args: RequestArgs(params: parameters, sessionId: sessionId))
        .continueOnSuccessWith(network.processingExecutor, continuation:
        {
            (response: NetworkResponse<String>) -> AuthToken in
            
            guard let value = response.response,
            let regex = try? NSRegularExpression(pattern: "access_token=([A-Za-z0-9\\-.]+)&expires=([0-9]+)", options: []) else
            {
                throw AuthError.invalidResponse
            }
            
            let matches = regex.matches(in: value, options: [], range: NSRange(location: 0, length: value.utf16.count))
            
            // Extract the access_token
            guard matches.count > 0 && matches[0].numberOfRanges >= 3,
            let tokenRange = matches[0].rangeAt(1).rangeForString(value) else
            {
                throw AuthError.invalidResponse
            }
            
            let token = value.substring(with: tokenRange)
            
            // Extract the expiry date
            guard let expiryRange = matches[0].rangeAt(2).rangeForString(value) else
            {
                throw AuthError.invalidResponse
            }
            
            let date = self.getDate(fromResponse: response)
            let expiryString = value.substring(with: expiryRange)
            guard let expiryTime = Int(expiryString) else
            {
                throw AuthError.invalidResponse
            }
            
            let expiryDate = date.addingTimeInterval(TimeInterval(expiryTime))
            return AuthToken(token: token, expiry: expiryDate)
        })
    }
    
    private func getDate<T>(fromResponse response: NetworkResponse<T>) -> Date
    {
        let formatter = DateFormatter()
        
        if let dateString = response.responseHeaders?["Date"],
        let date = formatter.date(from: dateString)
        {
            return date
        }
        
        return Date()
    }
    
    private func getError(forInvalidTicketResponse response: NetworkResponse<Data>) -> AuthError
    {
        if let responseData = response.response,
        let json = (try? JSONSerialization.jsonObject(with: responseData, options: JSONSerialization.ReadingOptions())) as? NSDictionary,
        let errors = json["errors"] as? [String],
        let error = errors.first
        {
            return AuthError.clientError(error)
        }
        
        return AuthError.invalidResponse
    }
}
