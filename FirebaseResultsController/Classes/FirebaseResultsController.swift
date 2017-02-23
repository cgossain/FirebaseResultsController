//
//  FirebaseResultsController.swift
//  Pods
//
//  Created by Christian Gossain on 2017-02-12.
//
//

import Foundation
import FirebaseDatabase

public enum ResultsChangeType: Int {
    case insert     = 1
    case delete     = 2
    case move       = 3
    case update     = 4
}


public enum FirebaseResultsControllerError: Error {
    case invalidIndexPath(row: Int, section: Int)
}


public protocol FirebaseResultsControllerDelegate: class {
    
    /// Notifies the delegate that a fetched object has been changed due to an add, remove, move, or update.
    func controller(_ controller: FirebaseResultsController, didChange anObject: FIRDataSnapshot, at indexPath: IndexPath?, for type: ResultsChangeType, newIndexPath: IndexPath?)
    
    /// Notifies the delegate of added or removed sections.
    func controller(_ controller: FirebaseResultsController, didChange section: Section, atSectionIndex sectionIndex: Int, for type: ResultsChangeType)
    
    /// Called when the results controller begins receiving changes.
    func controllerWillChangeContent(_ controller: FirebaseResultsController)
    
    /// Called when the controller has completed processing the all changes.
    func controllerDidChangeContent(_ controller: FirebaseResultsController)
    
}


public class FirebaseResultsController {
    
    /// The FirebaseFetchRequest instance used to do the fetching. The sort descriptor used in the request groups objects into sections.
    public let fetchRequest: FirebaseFetchRequest
    
    /// The keyPath on the fetched objects used to determine the section they belong to.
    public let sectionNameKeyPath: String?
    
    /// The object that is notified when the fetched results changed.
    public weak var delegate: FirebaseResultsControllerDelegate?
    
    /// The results of the fetch. Returns `nil` if `performFetch()` hasn't yet been called.
    public var fetchedObjects: [FIRDataSnapshot] { return currentFetchResult.results }

    /// The sections for the receiver’s fetch results.
    public var sections: [Section] { return currentFetchResult.sections }
    
    // firebase observer handles
    fileprivate var childAddedHandle: FIRDatabaseHandle = 0
    fileprivate var childChangedHandle: FIRDatabaseHandle = 0
    fileprivate var childMovedHandle: FIRDatabaseHandle = 0
    fileprivate var childRemovedHandle: FIRDatabaseHandle = 0
    fileprivate var valueHandle: FIRDatabaseHandle = 0
    
    /// A value that associates a call to `performFetch` with the data returned for that fetch.
    fileprivate var currentFetchHandle = 0
    
    /// A copy of the fetch request at the time performFetch() was called. Since the fetch request can be changed externally, we need to store a copy that represents the current fetch.
    fileprivate var activeFetchRequest: FirebaseFetchRequest!
    
    /// The batching controller for the current fetch request.
    fileprivate var batchingController: BatchingController!
    
    /// The current fetch results state.
    fileprivate var currentFetchResult: FetchResult!
    
    /// A flag that indicates whether the controller has fetched the initial data associated with the current fetch handle (i.e. first fetch after `perfomFetch` is called)
    fileprivate var didFetchInitialData = false
    
    
    /// Initializes the results controller with the given fetch request and an optional sectionNameKeyPath to section fetched data on.
    ///
    /// - parameters:
    ///   - fetchRequest: The fetch request that contains the firebase reference/query to fetch data from.
    ///   - sectionNameKeyPath: A key path on result objects that returns the section name. Pass nil to indicate that the controller should generate a single section.
    ///
    public init(fetchRequest: FirebaseFetchRequest, sectionNameKeyPath: String?) {
        self.fetchRequest = fetchRequest
        self.sectionNameKeyPath = sectionNameKeyPath
    }
    
    deinit {
        unregisterQueryObservers()
    }
    
    /**
     Executes the fetch described by the fetch request. You must call this method to start fetching the initial data and to setup the query observers.
     If you change the sort decriptors or predicate on the fetch request, you must call this method to reconfigure the receiver for the updated fetch request.
     */
    public func performFetch() {
        // detach exitsting observers
        unregisterQueryObservers()
        
        // increment the fetch handle
        currentFetchHandle += 1
        
        // create a new batching controller for this fetch
        batchingController = BatchingController()
        batchingController.delegate = self
        
        // update the active fetch request (specifically, we are interested in captur the state of the predicate and sort descriptors is what we are interested in here, since the query can't change)
        activeFetchRequest = fetchRequest.copy() as! FirebaseFetchRequest
        
        // reset the fetch result
        currentFetchResult = FetchResult(fetchRequest: activeFetchRequest, sectionNameKeyPath: sectionNameKeyPath)
        
        // attach new observers
        registerQueryObservers()
    }
    
    /// Returns the snapshot at a given indexPath.
    ///
    /// - parameters:
    ///     - at: An index path in the fetch results. If indexPath does not describe a valid index path in the fetch results, an error is thrown.
    ///
    /// - returns: The object at a given index path in the fetch results.
    public func object(at: IndexPath) throws -> FIRDataSnapshot {
        if at.section < sections.count {
            let section = sections[at.section]
            
            if at.row < section.numberOfObjects {
                return section.objects[at.row]
            }
        }
        
        throw FirebaseResultsControllerError.invalidIndexPath(row: at.row, section: at.section)
    }
    
    /// Returns the indexPath of a given snapshot.
    ///
    /// - parameters:
    ///     - for: An object in the receiver’s fetch results.
    ///
    /// - returns: The index path of object in the receiver’s fetch results, or nil if object could not be found.
    public func indexPath(for snapshot: FIRDataSnapshot) -> IndexPath? {
        return sections.lookup(snapshot: snapshot)?.path
    }
    
}

extension FirebaseResultsController {
    
    fileprivate func unregisterQueryObservers() {
        fetchRequest.query.removeObserver(withHandle: childAddedHandle)
        fetchRequest.query.removeObserver(withHandle: childChangedHandle)
        fetchRequest.query.removeObserver(withHandle: childMovedHandle)
        fetchRequest.query.removeObserver(withHandle: childRemovedHandle)
        fetchRequest.query.removeObserver(withHandle: valueHandle)
    }
    
    fileprivate func registerQueryObservers() {
        let handle = currentFetchHandle
        
        childAddedHandle = fetchRequest.query.observe(.childAdded, with: { [weak self] (snapshot) in
            guard let strongSelf = self else {
                return
            }
            
            if handle == strongSelf.currentFetchHandle {
                strongSelf.handle(inserted: snapshot)
            }
        })
        
        childChangedHandle = fetchRequest.query.observe(.childChanged, with: { [weak self] (snapshot) in
            guard let strongSelf = self else {
                return
            }
            
            if handle == strongSelf.currentFetchHandle {
                strongSelf.handle(changed: snapshot)
            }
        })
        
        childMovedHandle = fetchRequest.query.observe(.childMoved, with: { [weak self] (snapshot) in
            guard let strongSelf = self else {
                return
            }
            
            if handle == strongSelf.currentFetchHandle {
                strongSelf.handle(changed: snapshot)
            }
        })
        
        childRemovedHandle = fetchRequest.query.observe(.childRemoved, with: { [weak self] (snapshot) in
            guard let strongSelf = self else {
                return
            }
            
            if handle == strongSelf.currentFetchHandle {
                strongSelf.handle(removed: snapshot)
            }
        })
        
        valueHandle = fetchRequest.query.observe(.value, with: { [weak self] (snapshot) in
            guard let strongSelf = self else {
                return
            }
            
            if handle == strongSelf.currentFetchHandle {
//                if self.didFetchInitialData {
//                    return
//                }
//                self.didFetchInitialData = true
                
                // process the batch as soon as all the data is available
                strongSelf.batchingController.processBatch()
            }
        })
    }
    
}

extension FirebaseResultsController {
    
    fileprivate func handle(inserted: FIRDataSnapshot) {
        batchingController.insert(snapshot: inserted)
    }
    
    fileprivate func handle(changed: FIRDataSnapshot) {
        batchingController.change(snapshot: changed)
    }
    
    fileprivate func handle(removed: FIRDataSnapshot) {
        batchingController.remove(snapshot: removed)
    }
    
}

extension FirebaseResultsController: BatchingControllerDelegate {
    
    func controllerWillBeginBatchingChanges(_ controller: BatchingController) {
        delegate?.controllerWillChangeContent(self)
    }
    
    func controller(_ controller: BatchingController, finishedBatchingWithInserted inserted: Set<FIRDataSnapshot>, changed: Set<FIRDataSnapshot>, removed: Set<FIRDataSnapshot>) {
        let pendingFetchResult = FetchResult(fetchResult: currentFetchResult)
        
        // apply the changes to the pending results
        pendingFetchResult.apply(inserted: Array(inserted), updated: Array(changed), deleted: Array(removed))
        
        let diff = FetchResultDiff(from: currentFetchResult, to: pendingFetchResult, changedObjects: Array(changed))
        
        // apply the new results
        currentFetchResult = pendingFetchResult
        
        // notify the delegate about the exact changes
        notifyDelegateOfChanges(for: diff)
        
        // notify the delegate
        delegate?.controllerDidChangeContent(self)
    }
    
}

extension FirebaseResultsController {
    
    fileprivate func notifyDelegateOfChanges(for diff: FetchResultDiff) {
        
        // changed rows
        if let changedRows = diff.changedRows {
            for row in changedRows {
                delegate?.controller(self, didChange: row.value, at: row.indexPath, for: .update, newIndexPath: nil)
            }
        }
        
        // removed rows
        if let removedRows = diff.removedRows {
            for row in removedRows {
                delegate?.controller(self, didChange: row.value, at: row.indexPath, for: .delete, newIndexPath: nil)
            }
        }
        
        // removed sections
        if let removedSections = diff.removedSections {
            for section in removedSections {
                delegate?.controller(self, didChange: section.section, atSectionIndex: section.idx, for: .delete)
            }
        }
        
        // inserted sections
        if let insertedSections = diff.insertedSections {
            for section in insertedSections {
                delegate?.controller(self, didChange: section.section, atSectionIndex: section.idx, for: .insert)
            }
        }
        
        // inserted rows
        if let insertedRows = diff.insertedRows {
            for row in insertedRows {
                delegate?.controller(self, didChange: row.value, at: nil, for: .insert, newIndexPath: row.indexPath)
            }
        }
        
        // moved rows
        if let movedRows = diff.movedRows {
            for move in movedRows {
                delegate?.controller(self, didChange: move.to.value, at: move.from.indexPath, for: .move, newIndexPath: move.to.indexPath)
            }
        }
        
    }
    
}

extension FirebaseResultsController: Hashable {
    
    public static func ==(lhs: FirebaseResultsController, rhs: FirebaseResultsController) -> Bool {
        return lhs.fetchRequest.query == rhs.fetchRequest.query
    }
    
    public var hashValue: Int {
        // since the query cannot change this can be used to determine the equality
        return fetchRequest.query.hashValue
    }
    
}
