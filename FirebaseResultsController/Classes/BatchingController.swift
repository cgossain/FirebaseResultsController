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
    func controller(_ controller: BatchingController, finishedBatchingWithInserted inserted: Set<FIRDataSnapshot>, changed: Set<FIRDataSnapshot>, removed: Set<FIRDataSnapshot>)
}


class BatchingController {
    
    /// The object that will receive batching updates.
    weak var delegate: BatchingControllerDelegate?
    
    fileprivate var batchingInterval = 0.35
    fileprivate var isChanging = false
    fileprivate var batchingTimer: Timer?
    
    // MARK: - Public
    
    /// Notifies the controller of an inserted snapshot.
    func insert(snapshot: FIRDataSnapshot) {
        batch(inserted: Set([snapshot]), changed: nil, removed: nil)
    }
    
    /// Notifies the controller of a changed snapshot.
    func change(snapshot: FIRDataSnapshot) {
        batch(inserted: nil, changed: Set([snapshot]), removed: nil)
    }
    
    /// Notifies the controller of a removed snapshot.
    func remove(snapshot: FIRDataSnapshot) {
        batch(inserted: nil, changed: nil, removed: Set([snapshot]))
    }
    
    /// Forces the receiver to process changes immediately. This will terminate any running batching activity, and notify the delegate of the results.
    func processBatch() {
        // if the controller is not currently changing (i.e. `processBath` called when there is no active batching), we need to make sure that the calls to "will" and "did" change are balanced
        // so this method will make sure to call `controllerWillBeginBatchingChanges` if needed
        willChangeIfNeeded()
        
        var uniqueInserted: [String: FIRDataSnapshot] = [:]
        var uniqueChanged: [String: FIRDataSnapshot] = [:]
        var uniqueRemoved: [String: FIRDataSnapshot] = [:]
        
        // extract the data from the active timer
        if let timer = batchingTimer, let batch = timer.userInfo as? [String: [String: FIRDataSnapshot]] {
            timer.invalidate()
            batchingTimer = nil;
            
            // extract changes from user info
            let insertedByRefDescription = batch[BatchingControllerInsertedKey] ?? [String: FIRDataSnapshot]()
            let changedByRefDescription = batch[BatchingControllerChangedKey] ?? [String: FIRDataSnapshot]()
            let removedByRefDescription = batch[BatchingControllerRemovedKey] ?? [String: FIRDataSnapshot]()
            
            // group into unique changes
            uniqueInserted = insertedByRefDescription
            uniqueChanged = changedByRefDescription
            uniqueRemoved = removedByRefDescription
            
            // it's possible that the same snapshot could have been inserted and changed withing the same batching interval
            // we need to detect this case, and reroute the change as an insert
            for (key, value) in changedByRefDescription {
                if let inserted = insertedByRefDescription[key] {
                    // this `changed` version also appears as `inserted`; update the version in the `inserted` list with this newer version
                    uniqueInserted[key] = value
                    
                    // remove this object from the `changed` list since, taken from the perspective of the entire batch, it was effectively inserted
                    uniqueChanged[key] = nil
                }
            }
        }
        
        // finish the batch
        isChanging = false
        
        // notify the delegate
        delegate?.controller(self, finishedBatchingWithInserted: Set(uniqueInserted.values), changed: Set(uniqueChanged.values), removed: Set(uniqueRemoved.values))
    }
    
}

extension BatchingController {
    
    /// Calls `controllerWillBeginBatchingChanges` if the controller is not currently changing.
    fileprivate func willChangeIfNeeded() {
        // notify the delegate if we haven't yet for the current batch
        if !isChanging {
            isChanging = true
            
            delegate?.controllerWillBeginBatchingChanges(self)
        }
    }
    
    fileprivate func batch(inserted: Set<FIRDataSnapshot>?, changed: Set<FIRDataSnapshot>?, removed: Set<FIRDataSnapshot>?) {
        // calls `controllerWillBeginBatchingChanges` if needed
        willChangeIfNeeded()
        
        var pendingInserted = [String: FIRDataSnapshot]()
        var pendingChanged = [String: FIRDataSnapshot]()
        var pendingRemoved = [String: FIRDataSnapshot]()
        
        // grab the existing user info from any currently running batching timer
        if let timer = batchingTimer, timer.isValid {
            if let userInfo = timer.userInfo as? [String: [String: FIRDataSnapshot]] {
                
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
    }
    
    @objc fileprivate func batchingTimerFired(_ timer: Timer) {
        processBatch()
    }
    
}
