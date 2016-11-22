//
//  MemoryCookieStorage.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/08/04.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

final class MemoryCookieStorage: HTTPCookieStorage, Synchronizable
{
    private var internalCookies: [HTTPCookie] = []
    let synchronizationLock: DispatchQueue = DispatchQueue(label: "MemoryCookieStorage Synchronization", attributes: [])
    
    override func setCookie(_ cookie: HTTPCookie)
    {
        if cookieAcceptPolicy != .never
        {
            sync
            {
                if let cookieIdx = self.indexOf(cookie: cookie)
                {
                    self.internalCookies[cookieIdx] = cookie
                }
                else
                {
                    self.internalCookies.append(cookie)
                }
            }
        }
    }
    
    override func deleteCookie(_ cookie: HTTPCookie)
    {
        sync
        {
            if let cookieIdx = self.indexOf(cookie: cookie)
            {
                self.internalCookies.remove(at: cookieIdx)
            }
        }
    }
    
    override var cookies: [HTTPCookie]?
    {
        return sync { return self.internalCookies }
    }
    
    override func cookies(for URL: URL) -> [HTTPCookie]?
    {
        var array: [HTTPCookie] = []
        let path = URL.path
        guard let host = URL.host else
        {
            return array
        }
        
        sync
        {
            for cookie in self.internalCookies
            {
                if !cookie.matches(domain: host)
                {
                    continue
                }
                if !cookie.matches(path: path)
                {
                    continue
                }
                if cookie.isSecure && URL.scheme?.caseInsensitiveCompare("https") != .orderedSame
                {
                    continue
                }
                
                array.append(cookie)
            }
        }
        
        return array.sorted(
        by: {
            (c1, c2) -> Bool in
            // More specific cookies, i.e. matching the longest portion of the path, come first
            let path1Length = c1.path.characters.count
            let path2Length = c2.path.characters.count
            return path1Length > path2Length
        })
    }
    
    override func sortedCookies(using sortOrder: [NSSortDescriptor]) -> [HTTPCookie]
    {
        let cookies = sync { return self.internalCookies }
        return cookies.sorted(
        by: {
            (c1, c2) -> Bool in
            for descriptor in sortOrder
            {
                switch descriptor.compare(c1, to: c2)
                {
                case .orderedAscending: return true
                case .orderedDescending: return false
                case .orderedSame: continue
                }
            }
            return true
        })
    }
    
    override func getCookiesFor(_ task: URLSessionTask, completionHandler: @escaping ([HTTPCookie]?) -> Void)
    {
        guard let url = task.currentRequest?.url else
        {
            completionHandler(nil)
            return
        }
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async 
        {
            completionHandler(self.cookies(for: url))
        }
    }
    
    override func setCookies(_ cookies: [HTTPCookie], for URL: URL?, mainDocumentURL: URL?)
    {
        let host = mainDocumentURL?.host
        sync
        {
            for cookie in cookies
            {
                switch self.cookieAcceptPolicy
                {
                case .always:
                    self.setCookieUnsynchronized(cookie: cookie)
                case .never:
                    break
                case .onlyFromMainDocumentDomain:
                    if host == nil || cookie.matches(domain: host!)
                    {
                        self.setCookieUnsynchronized(cookie: cookie)
                    }
                }
            }
        }
    }
    
    override func storeCookies(_ cookies: [HTTPCookie], for task: URLSessionTask)
    {
        let mainDocUrl = task.currentRequest?.url ?? task.originalRequest?.mainDocumentURL ?? task.originalRequest?.url
        setCookies(cookies, for: task.currentRequest?.url, mainDocumentURL: mainDocUrl)
    }
    
    // Precondition: must be called within a sync() closure
    private func indexOf(cookie: HTTPCookie) -> Int?
    {
        return internalCookies.index(
        where: {
            (target) -> Bool in
            let equalName = target.name.caseInsensitiveCompare(cookie.name) == .orderedSame
            let equalDomain = target.domain.caseInsensitiveCompare(cookie.domain) == .orderedSame
            let equalPath = target.path == cookie.path
            return equalName && equalDomain && equalPath
        })
    }
    
    private func setCookieUnsynchronized(cookie: HTTPCookie)
    {
        if cookieAcceptPolicy != .never
        {
            if let cookieIdx = self.indexOf(cookie: cookie)
            {
                self.internalCookies[cookieIdx] = cookie
            }
            else
            {
                self.internalCookies.append(cookie)
            }
        }
    }
}

private extension String
{
    func hasCaseInsensitiveSuffix(_ suffix: String) -> Bool
    {
        return range(of: suffix, options: [.caseInsensitive, .anchored, .backwards]) != nil
    }
}

private extension HTTPCookie
{
    func matches(domain: String) -> Bool
    {
        var matches = self.domain.caseInsensitiveCompare(domain) == .orderedSame
        matches = matches || (self.domain.hasPrefix(".") && domain.hasCaseInsensitiveSuffix(self.domain))
        matches = matches || domain.hasCaseInsensitiveSuffix(".\(self.domain)")
        return matches
    }
    
    func matches(path: String?) -> Bool
    {
        return self.path.characters.count == 0 || self.path == "/" || (path?.hasPrefix(self.path) ?? false)
    }
}
