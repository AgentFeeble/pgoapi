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

extension Synchronizable where LockType == DispatchQueue
{
    func sync(_ closure: () -> ())
    {
        synchronizationLock.sync(execute: closure)
    }
    
    @discardableResult
    func sync<T>(_ closure: () -> T) -> T
    {
        var value: T? = nil
        synchronizationLock.sync
        {
            value = closure()
        }
        return value!
    }
}

extension Synchronizable where LockType == Lockable
{
    func sync(_ closure: () -> ())
    {
        synchronizationLock.lock()
        defer { synchronizationLock.unlock() }
        closure()
    }
    
    @discardableResult
    func sync<T>(_ closure: () -> T) -> T
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
