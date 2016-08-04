//
//  Synchronizable.swift
//  pgoapi
//
//  Created by Rayman Rosevear on 2016/08/04.
//  Copyright © 2016 MC. All rights reserved.
//

import Foundation

protocol Synchronizable
{
    associatedtype LockType
    var synchronizationLock: LockType { get }
}

protocol Lockable
{
    func lock()
    func unlock()
}

extension Synchronizable where LockType == dispatch_queue_t
{
    func sync(closure: () -> ())
    {
        dispatch_sync(synchronizationLock, closure)
    }
    
    func sync<T>(closure: () -> T) -> T
    {
        var value: T? = nil
        dispatch_sync(synchronizationLock)
        {
            value = closure()
        }
        return value!
    }
}

extension Synchronizable where LockType == Lockable
{
    func sync(@noescape closure: () -> ())
    {
        synchronizationLock.lock()
        defer { synchronizationLock.unlock() }
        closure()
    }
    
    func sync<T>(@noescape closure: () -> T) -> T
    {
        synchronizationLock.lock()
        defer { synchronizationLock.unlock() }
        return closure()
    }
}

class SpinLock: Lockable
{
    private var spinLock: OSSpinLock = OS_SPINLOCK_INIT
    
    func lock()
    {
        OSSpinLockLock(&spinLock)
    }
    
    func unlock()
    {
        OSSpinLockUnlock(&spinLock)
    }
}
