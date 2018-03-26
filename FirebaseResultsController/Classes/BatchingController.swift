//
//  BatchingController.swift
//
//  Copyright (c) 2017-2018 Christian Gossain
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import FirebaseDatabase

protocol BatchingControllerDelegate: class {
    /// Called when the controller is about to begin batching changes.
    func controllerWillBeginBatchingChanges(_ controller: BatchingController)
    
    /// Called when the controller has finished batching changes, passing the sets of inserts, changes, and removed snapshots.
    func controller(_ controller: BatchingController, finishedBatchingWithInserted inserted: Set<DataSnapshot>, changed: Set<DataSnapshot>, removed: Set<DataSnapshot>)
}

/// An internal class used to group incoming results into a single batch of changes. The batching controller will process an active batch after _batchingInterval_ seconds
/// have elapsed since an object was last inserted, removed or changed. Each time an object is inserted, removed or changed, the internal timer is reset. Otherwise you can
/// process an active batch immediately by calling `processBatch()`.
class BatchingController {
    /// The object that will receive batching updates.
    weak var delegate: BatchingControllerDelegate?
    
    /// The time interval (in seconds) to wait for changes to stop before processing the batch.
    var batchingInterval = 0.3
    
    /// Set to true if changes should no be batched, but rather processed as soon as they are received.
    var processesChangesImmediately = false
    
    /// Indicates if the controller is currently batching.
    fileprivate(set) var isBatching = false
    
    /// The internal batching timer.
    fileprivate var batchingTimer: Timer?
    
    
    // MARK: - Public
    /// Notifies the controller of an inserted snapshot.
    func insert(_ snapshot: DataSnapshot) {
        batch(inserted: Set([snapshot]), changed: [], removed: [])
    }
    
    /// Notifies the controller of a changed snapshot.
    func update(_ snapshot: DataSnapshot) {
        batch(inserted: [], changed: Set([snapshot]), removed: [])
    }
    
    /// Notifies the controller of a removed snapshot.
    func remove(_ snapshot: DataSnapshot) {
        batch(inserted: [], changed: [], removed: Set([snapshot]))
    }
    
    /// Forces the receiver to process changes immediately. This will terminate any running batching activity, and notify the delegate of the results.
    func processBatch() {
        // if the controller is not currently batching (i.e. `processBatch()` called when there is no active batching), we need to make sure that we are still
        // making balanced calls to "will" and "did" change delegate methods; this method ensures that `controllerWillBeginBatchingChanges` is called if needed
        notifyWillBeginBatchingIfNeeded()
        
        // deduplicate the batch into these unique maps (i.e. a snapshot could have been inserted and changed within the same batch)
        var uniqueInserted: [String: DataSnapshot] = [:]
        var uniqueChanged: [String: DataSnapshot] = [:]
        var uniqueRemoved: [String: DataSnapshot] = [:]
        
        // extract the data from the active timer
        if let timer = batchingTimer {
            // extract and deduplicate changes container in the userInfo
            if let batch = timer.userInfo as? [BatchingKey: [String: DataSnapshot]] {
                let insertedInBatch = batch[.inserted] ?? [String: DataSnapshot]()
                let changedInBatch = batch[.changed] ?? [String: DataSnapshot]()
                let removedInBatch = batch[.removed] ?? [String: DataSnapshot]()
                
                // copy batch objects in the unique variables
                uniqueInserted = insertedInBatch
                uniqueChanged = changedInBatch
                uniqueRemoved = removedInBatch
                
                // it's possible that the same snapshot could have been inserted and changed withing the same batching interval
                // we need to detect this case, and reroute the change as an insert
                for (key, value) in changedInBatch {
                    if insertedInBatch[key] != nil {
                        // this `changed` version also appears as `inserted`; update the version in the `inserted` list with this newer version
                        uniqueInserted[key] = value
                        
                        // remove this object from the `changed` list since, taken from the perspective of the entire batch, it was effectively inserted
                        uniqueChanged[key] = nil
                    }
                }
            }
            
            // cleanup the timer
            timer.invalidate()
            batchingTimer = nil;
        }
        
        // finish the batch
        isBatching = false
        
        // notify the delegate
        delegate?.controller(self, finishedBatchingWithInserted: Set(uniqueInserted.values), changed: Set(uniqueChanged.values), removed: Set(uniqueRemoved.values))
    }
    
}

fileprivate extension BatchingController {
    enum BatchingKey {
        case inserted
        case changed
        case removed
    }
    
    /// Internal method that calls `controllerWillBeginBatchingChanges` if the controller is not currently batching. Otherwise does nothing.
    func notifyWillBeginBatchingIfNeeded() {
        if !isBatching {
            isBatching = true
            
            // notify the delegate that we are about to being batching
            delegate?.controllerWillBeginBatchingChanges(self)
        }
    }
    
    /// Internal method used to add objects to the a currently active batch, or to start a new batch.
    func batch(inserted: Set<DataSnapshot>, changed: Set<DataSnapshot>, removed: Set<DataSnapshot>) {
        notifyWillBeginBatchingIfNeeded()
        
        // add the new batch of objects to any pending batch contained in the timer user info
        var pendingInserted = [String: DataSnapshot]()
        var pendingChanged = [String: DataSnapshot]()
        var pendingRemoved = [String: DataSnapshot]()
        
        // extract the data from the active timer
        if let timer = batchingTimer, timer.isValid {
            if let userInfo = timer.userInfo as? [BatchingKey: [String: DataSnapshot]] {
                if let pending = userInfo[.inserted] {
                    pendingInserted = pending
                }
                
                if let pending = userInfo[.changed] {
                    pendingChanged = pending
                }
                
                if let pending = userInfo[.removed] {
                    pendingRemoved = pending
                }
            }
            
            // invalidate the existing timer
            timer.invalidate()
        }
        
        // add the new objects to the current batch
        inserted.forEach({ (snapshot) in pendingInserted[snapshot.ref.description] = snapshot })
        changed.forEach({ (snapshot) in pendingChanged[snapshot.ref.description] = snapshot })
        removed.forEach({ (snapshot) in pendingRemoved[snapshot.ref.description] = snapshot })
        
        // schedule a new timer
        let userInfo: [BatchingKey: [String: DataSnapshot]] = [.inserted : pendingInserted, .changed : pendingChanged, .removed : pendingRemoved]
        batchingTimer = Timer.scheduledTimer(timeInterval: batchingInterval, target: self, selector: #selector(BatchingController.batchingTimerFired(_:)), userInfo: userInfo, repeats: false)
        
        // process the changes immediately if needed
        if processesChangesImmediately {
            processBatch()
        }
    }
}

fileprivate extension BatchingController {
    @objc func batchingTimerFired(_ timer: Timer) {
        processBatch()
    }
}

