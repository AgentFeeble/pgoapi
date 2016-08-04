//
//  MemoryCookieStorage.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/08/04.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

final class MemoryCookieStorage: NSHTTPCookieStorage, Synchronizable
{
    private var internalCookies: [NSHTTPCookie] = []
    let synchronizationLock: dispatch_queue_t = dispatch_queue_create("MemoryCookieStorage Synchronization", nil)
    
    override func setCookie(cookie: NSHTTPCookie)
    {
        if cookieAcceptPolicy != .Never
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
    
    override func deleteCookie(cookie: NSHTTPCookie)
    {
        sync
        {
            if let cookieIdx = self.indexOf(cookie: cookie)
            {
                self.internalCookies.removeAtIndex(cookieIdx)
            }
        }
    }
    
    override var cookies: [NSHTTPCookie]?
    {
        return sync { return self.internalCookies }
    }
    
    override func cookiesForURL(URL: NSURL) -> [NSHTTPCookie]?
    {
        var array: [NSHTTPCookie] = []
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
                if cookie.secure && URL.scheme.caseInsensitiveCompare("https") != .OrderedSame
                {
                    continue
                }
                
                array.append(cookie)
            }
        }
        
        return array.sort(
        {
            (c1, c2) -> Bool in
            // More specific cookies, i.e. matching the longest portion of the path, come first
            let path1Length = c1.path.characters.count
            let path2Length = c2.path.characters.count
            return path1Length > path2Length
        })
    }
    
    override func sortedCookiesUsingDescriptors(sortOrder: [NSSortDescriptor]) -> [NSHTTPCookie]
    {
        let cookies = sync { return self.internalCookies }
        return cookies.sort(
        {
            (c1, c2) -> Bool in
            for descriptor in sortOrder
            {
                switch descriptor.compareObject(c1, toObject: c2)
                {
                case .OrderedAscending: return true
                case .OrderedDescending: return false
                case .OrderedSame: continue
                }
            }
            return true
        })
    }
    
    override func getCookiesForTask(task: NSURLSessionTask, completionHandler: ([NSHTTPCookie]?) -> Void)
    {
        guard let url = task.currentRequest?.URL else
        {
            completionHandler(nil)
            return
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))
        {
            completionHandler(self.cookiesForURL(url))
        }
    }
    
    override func setCookies(cookies: [NSHTTPCookie], forURL URL: NSURL?, mainDocumentURL: NSURL?)
    {
        let host = mainDocumentURL?.host
        sync
        {
            for cookie in cookies
            {
                switch self.cookieAcceptPolicy
                {
                case .Always:
                    self.setCookieUnsynchronized(cookie: cookie)
                case .Never:
                    break
                case .OnlyFromMainDocumentDomain:
                    if host == nil || cookie.matches(domain: host!)
                    {
                        self.setCookieUnsynchronized(cookie: cookie)
                    }
                }
            }
        }
    }
    
    override func storeCookies(cookies: [NSHTTPCookie], forTask task: NSURLSessionTask)
    {
        let mainDocUrl = task.currentRequest?.URL ?? task.originalRequest?.mainDocumentURL ?? task.originalRequest?.URL
        setCookies(cookies, forURL: task.currentRequest?.URL, mainDocumentURL: mainDocUrl)
    }
    
    // Precondition: must be called within a sync() closure
    private func indexOf(cookie cookie: NSHTTPCookie) -> Int?
    {
        return internalCookies.indexOf(
        {
            (target) -> Bool in
            let equalName = target.name.caseInsensitiveCompare(cookie.name) == .OrderedSame
            let equalDomain = target.domain.caseInsensitiveCompare(cookie.domain) == .OrderedSame
            let equalPath = target.path == cookie.path
            return equalName && equalDomain && equalPath
        })
    }
    
    private func setCookieUnsynchronized(cookie cookie: NSHTTPCookie)
    {
        if cookieAcceptPolicy != .Never
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
    func hasCaseInsensitiveSuffix(suffix: String) -> Bool
    {
        return rangeOfString(suffix, options: [.CaseInsensitiveSearch, .AnchoredSearch, .BackwardsSearch]) != nil
    }
}

private extension NSHTTPCookie
{
    func matches(domain domain: String) -> Bool
    {
        var matches = self.domain.caseInsensitiveCompare(domain) == .OrderedSame
        matches = matches || (self.domain.hasPrefix(".") && domain.hasCaseInsensitiveSuffix(self.domain))
        matches = matches || domain.hasCaseInsensitiveSuffix(".\(self.domain)")
        return matches
    }
    
    func matches(path path: String?) -> Bool
    {
        return self.path.characters.count == 0 || self.path == "/" || (path?.hasPrefix(self.path) ?? false)
    }
}
