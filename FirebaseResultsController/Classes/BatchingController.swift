//
//  BatchingController.swift
//  Pods
//
//  Created by Christian Gossain on 2017-02-14.
//
//

import Foundation
import FirebaseDatabase


fileprivate let BatchingControllerInsertedKey = "inserted"
fileprivate let BatchingControllerChangedKey = "changed"
fileprivate let BatchingControllerRemovedKey = "removed"


protocol BatchingControllerDelegate: class {
    /// Called when the controller is about to begin batching changes.
    func controllerWillBeginBatchingChanges(_ controller: BatchingController)
    
    /// Called when the controller has finished batching changes, passing the sets of inserts, changes, and removed snapshots.
    func controller(_ controller: BatchingController, finishedBatchingWithInserted inserted: Set<DataSnapshot>, changed: Set<DataSnapshot>, removed: Set<DataSnapshot>)
}


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
    
    /// Kicks off an empty batch. This triggers the delegate to at least fire once.
    func notify() {
        batch(inserted: [], changed: [], removed: [])
    }
    
    /// Notifies the controller of an inserted snapshot.
    func insert(snapshot: DataSnapshot) {
        batch(inserted: Set([snapshot]), changed: nil, removed: nil)
    }
    
    /// Notifies the controller of a changed snapshot.
    func change(snapshot: DataSnapshot) {
        batch(inserted: nil, changed: Set([snapshot]), removed: nil)
    }
    
    /// Notifies the controller of a removed snapshot.
    func remove(snapshot: DataSnapshot) {
        batch(inserted: nil, changed: nil, removed: Set([snapshot]))
    }
    
    /// Forces the receiver to process changes immediately. This will terminate any running batching activity, and notify the delegate of the results.
    func processBatch() {
        // if the controller is not currently changing (i.e. `processBath` called when there is no active batching), we need to make sure that the calls to "will" and "did" change are balanced
        // so this method will make sure to call `controllerWillBeginBatchingChanges` if needed
        notifyWillBeginBatchingIfNeeded()
        
        var uniqueInserted: [String: DataSnapshot] = [:]
        var uniqueChanged: [String: DataSnapshot] = [:]
        var uniqueRemoved: [String: DataSnapshot] = [:]
        
        // extract the data from the active timer
        if let timer = batchingTimer {
            // extract and deduplicate changes container in the userInfo
            if let batch = timer.userInfo as? [String: [String: DataSnapshot]] {
                let insertedByRefDescription = batch[BatchingControllerInsertedKey] ?? [String: DataSnapshot]()
                let changedByRefDescription = batch[BatchingControllerChangedKey] ?? [String: DataSnapshot]()
                let removedByRefDescription = batch[BatchingControllerRemovedKey] ?? [String: DataSnapshot]()
                
                // group into unique changes
                uniqueInserted = insertedByRefDescription
                uniqueChanged = changedByRefDescription
                uniqueRemoved = removedByRefDescription
                
                // it's possible that the same snapshot could have been inserted and changed withing the same batching interval
                // we need to detect this case, and reroute the change as an insert
                for (key, value) in changedByRefDescription {
                    if insertedByRefDescription[key] != nil {
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

extension BatchingController {
    
    /// Calls `controllerWillBeginBatchingChanges` if the controller is not currently changing.
    fileprivate func notifyWillBeginBatchingIfNeeded() {
        // notify the delegate if we haven't yet for the current batch
        if !isBatching {
            isBatching = true
            
            delegate?.controllerWillBeginBatchingChanges(self)
        }
    }
    
    fileprivate func batch(inserted: Set<DataSnapshot>?, changed: Set<DataSnapshot>?, removed: Set<DataSnapshot>?) {
        // calls `controllerWillBeginBatchingChanges` if needed
        notifyWillBeginBatchingIfNeeded()
        
        var pendingInserted = [String: DataSnapshot]()
        var pendingChanged = [String: DataSnapshot]()
        var pendingRemoved = [String: DataSnapshot]()
        
        // grab the existing user info from any currently running batching timer
        if let timer = batchingTimer, timer.isValid {
            if let userInfo = timer.userInfo as? [String: [String: DataSnapshot]] {
                
                if let pending = userInfo[BatchingControllerInsertedKey] {
                    pendingInserted = pending
                }
                
                if let pending = userInfo[BatchingControllerChangedKey] {
                    pendingChanged = pending
                }
                
                if let pending = userInfo[BatchingControllerRemovedKey] {
                    pendingRemoved = pending
                }
            }
            
            // invalidate the existing timer
            timer.invalidate()
        }
        
        // add the new objects to the current batch
        inserted?.forEach({ (snapshot) in
            pendingInserted[snapshot.ref.description] = snapshot
        })
        
        changed?.forEach({ (snapshot) in
            pendingChanged[snapshot.ref.description] = snapshot
        })
        
        removed?.forEach({ (snapshot) in
            pendingRemoved[snapshot.ref.description] = snapshot
        })
        
        // schedule a new timer
        let userInfo = [
            BatchingControllerInsertedKey: pendingInserted,
            BatchingControllerChangedKey: pendingChanged,
            BatchingControllerRemovedKey: pendingRemoved,
        ]
        
        batchingTimer = Timer.scheduledTimer(timeInterval: batchingInterval, target: self, selector: #selector(BatchingController.batchingTimerFired(_:)), userInfo: userInfo, repeats: false)
        
        // process the changes immediately if needed
        if processesChangesImmediately {
            processBatch()
        }
    }
    
    @objc fileprivate func batchingTimerFired(_ timer: Timer) {
        processBatch()
    }
    
}
