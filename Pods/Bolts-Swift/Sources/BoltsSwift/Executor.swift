/*
 *  Copyright (c) 2016, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 */

import Foundation

/// `Executor` is an `enum`, that defines different strategies for calling closures.
public enum Executor {

    /**
     Calls closures immediately unless the call stack gets too deep,
     in which case it dispatches the closure in the default priority queue.
     */
    case Default

    /**
     Calls closures immediately.
     Tasks continuations will be run in the thread of the previous task.
     */
    case Immediate

    /**
     Calls closures on the main thread.
     Will execute synchronously if already on the main thread, otherwise - will execute asynchronously.
     */
    case MainThread

    /**
     Dispatches closures on a GCD queue.
     */
    case Queue(dispatch_queue_t)

    /**
     Adds closures to an operation queue.
     */
    case OperationQueue(NSOperationQueue)

    /**
     Passes closures to an executing closure.
     */
    case Closure((() -> Void) -> Void)

    /**
     Executes the given closure using the corresponding strategy.

     - parameter closure: The closure to execute.
     */
    public func execute(closure: () -> Void) {
        switch self {
        case .Default:
            struct Static {
                static let taskDepthKey = "com.bolts.TaskDepthKey"
                static let maxTaskDepth = 20
            }

            let localThreadDictionary = NSThread.currentThread().threadDictionary

            var previousDepth: Int
            if let depth = localThreadDictionary[Static.taskDepthKey] as? Int {
                previousDepth = depth
            } else {
                previousDepth = 0
            }

            if previousDepth > Static.maxTaskDepth {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), closure)
            } else {
                localThreadDictionary[Static.taskDepthKey] = previousDepth + 1
                closure()
                localThreadDictionary[Static.taskDepthKey] = previousDepth
            }
        case .Immediate:
            closure()
        case .MainThread:
            if NSThread.isMainThread() {
                closure()
            } else {
                dispatch_async(dispatch_get_main_queue(), closure)
            }
        case .Queue(let queue):
            dispatch_async(queue, closure)
        case .OperationQueue(let operationQueue):
            operationQueue.addOperationWithBlock(closure)
        case .Closure(let executingClosure):
            executingClosure(closure)
        }
    }
}

extension Executor : CustomStringConvertible, CustomDebugStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        switch self {
        case .Default:
            return "Default Executor"
        case .Immediate:
            return "Immediate Executor"
        case .MainThread:
            return "MainThread Executor"
        case .Queue:
            return "Executor with dispatch_queue"
        case .OperationQueue:
            return "Executor with NSOperationQueue"
        case .Closure:
            return "Executor with custom closure"
        }
    }

    /// A textual representation of `self`, suitable for debugging.
    public var debugDescription: String {
        switch self {
        case .Queue(let object):
            return "\(description): \(object)"
        case .OperationQueue(let queue):
            return "\(description): \(queue)"
        case .Closure(let closure):
            return "\(description): \(closure)"
        default:
            return description
        }
    }
}
