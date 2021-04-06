//
//  BatchController.swift
//
//  Copyright (c) 2017-2019 Christian Gossain
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
import Debounce

protocol BatchControllerDelegate: class {
    /// Called when the controller is about to begin tracking a new batch of changes.
    func controllerWillBeginBatchingChanges(_ controller: BatchController)
    
    /// Called when the controller has finished batching changes, passing the sets of inserts, changes, and removed snapshots.
    func controller(_ controller: BatchController, finishedBatchingWithInserted inserted: Set<DataSnapshot>, changed: Set<DataSnapshot>, removed: Set<DataSnapshot>)
}

/// A controller object used to group incoming changes into a single batch of changes.
///
/// Using an internal throttler, the batch controller resets a timer (currently 0.3 seconds) each time a new change is added to the batch. In some cases you
/// may want to process a batch immediatly, in this case you can call the `processBatch()` method. If the controller should always process changes
/// immediatly, simply set the `processesChangesImmediately` property to `true`.
final class BatchController {
    /// A unique identifier for the batch controller.
    public var identifier: String { return throttler.id }
    
    /// The object that will receive batching updates.
    weak var delegate: BatchControllerDelegate?
    
    /// Set to true if changes should no be batched, but rather processed as soon as they are received.
    var processesChangesImmediately = false
    
    /// Indicates if the controller is currently batching.
    private(set) var isBatching = false
    
    
    // MARK: - Private Properties
    /// The internal throttler.
    private let throttler = Throttler(throttlingInterval: 0.3)
    
    /// Returns the current batch being managed by the receiver.
    private var batch: Batch {
        // return the existing batch
        if let existingBatch = _batch {
            return existingBatch
        }
        
        // otherwise, create a new batch
        let newBatch = Batch()
        _batch = newBatch
        return newBatch
    }
    
    /// The backing ivar for the current batch.
    private var _batch: Batch?
    
    
    // MARK: - Lifecycle
    /// Tracks the snapshot as an insertion in the current batch.
    func insert(_ snapshot: DataSnapshot) {
        enqueue(snapshot, with: .insert)
    }
    
    /// Tracks the snapshot as an update in the current batch.
    ///
    /// - Note: If this snapshot was previously tracked as an insertion, it will remain as an insertion but the updated version will be used instead.
    func update(_ snapshot: DataSnapshot) {
        enqueue(snapshot, with: .update)
    }
    
    /// Tracks the snapshot as a removal in the current batch.
    ///
    /// - Note: If this snapshot was previously tracked as an insertion, calling this method will cancel out the previous insertion and there will be no net change in the batch.
    func remove(_ snapshot: DataSnapshot) {
        enqueue(snapshot, with: .remove)
    }
    
    /// Forces the receiver to process changes immediately. This will terminate any running batching activity, and notify the delegate of the results.
    func processBatch() {
        throttler.throttle(fireNow: true) {
            self.flush()
        }
    }
    
}

extension BatchController {
    private enum BatchOperation {
        case insert
        case update
        case remove
    }
    
    private func enqueue(_ snapshot: DataSnapshot, with op: BatchOperation) {
        // enqueue writes to the batch onto the throttlers serial queue
        throttler.queue.async {
            self.notifyWillBeginBatchingIfNeeded()
        }
        
        // enqueue writes to the batch onto the throttlers serial queue
        switch op {
        case .insert:
            throttler.queue.async {
                self.batch.insert(snapshot)
            }
        case .update:
            throttler.queue.async {
                self.batch.update(snapshot)
            }
        case .remove:
            throttler.queue.async {
                self.batch.remove(snapshot)
            }
        }
        
        // throttle the flush; the throttler uses a serial execution queue so while chunks of work keep getting
        // enqueue above, this chunk of work effectively will keep moving to the end of the execution queue until
        // no more writes are enqueued for the throttling interval
        throttler.throttle(fireNow: processesChangesImmediately) {
            self.flush()
        }
    }
    
    /// Internal method that calls `controllerWillBeginBatchingChanges` if the controller is not currently batching. Otherwise does nothing.
    private func notifyWillBeginBatchingIfNeeded() {
        if !isBatching {
            isBatching = true
            
            // notify the delegate
            DispatchQueue.main.async {
                self.delegate?.controllerWillBeginBatchingChanges(self)
            }
        }
    }
    
    /// Closes out the current batch of changes and notifies the delegate.
    private func flush() {
        if let batch = _batch {
            // flush the batch
            let results = batch.flush()
            
            // clear the reference to the current batch
            _batch = nil
            
            // finish the batch
            isBatching = false
            
            // notify the delegate
            DispatchQueue.main.async {
                self.delegate?.controller(self, finishedBatchingWithInserted: Set(results.inserted.values), changed: Set(results.changed.values), removed: Set(results.removed.values))
            }
        }
        else {
            // notify the delegate
            DispatchQueue.main.async {
                self.delegate?.controller(self, finishedBatchingWithInserted: [], changed: [], removed: [])
            }
        }
    }
}
