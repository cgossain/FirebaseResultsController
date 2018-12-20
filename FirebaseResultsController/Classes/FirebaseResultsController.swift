//
//  FirebaseResultsController.swift
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
    /// Called when the results controller begins receiving changes.
    func controllerWillChangeContent(_ controller: FirebaseResultsController)
    
    /// Called when the controller has completed processing the all changes.
    func controllerDidChangeContent(_ controller: FirebaseResultsController)
}

public protocol FirebaseResultsControllerChangeTracking: class {
    /// Notifies the change tracker that the controller has finished tracking all changes, and provides the results of the diff.
    func controller(_ controller: FirebaseResultsController, didChangeContentWith changes: FetchResultChanges)
}

public class FirebaseResultsController {
    public enum State {
        /// The controller has been initialized, but an initial call to `performFetch()` has not yet been made.
        case initial
        
        /// Currently loading the fetch request and setting up the observers. Initial data has not been fully fetched.
        case loading
        
        /// Fetch request has been loaded, and initial data has been fetched.
        case loaded
    }
    
    /// The FirebaseFetchRequest instance used to do the fetching. The sort descriptor used in the request groups objects into sections.
    public let fetchRequest: FirebaseFetchRequest
    
    /// The keyPath on the fetched objects used to determine the section they belong to.
    public let sectionNameKeyPath: String?
    
    /// The object that is notified when the fetched results change.
    public weak var delegate: FirebaseResultsControllerDelegate?
    
    /// The object that is notified of the diff results when the receiver's contents are changed.
    public weak var changeTracker: FirebaseResultsControllerChangeTracking?
    
    /// The results of the fetch. Returns `nil` if `performFetch()` hasn't yet been called.
    public var fetchedObjects: [DataSnapshot] { return currentFetchResult.results }

    /// The sections for the receiver’s fetch results.
    public var sections: [ResultsSection] { return currentFetchResult.sections }
    
    /// The current state of the controller.
    public fileprivate(set) var state: State = .initial
    
    
    // MARK: - Private Properties
    fileprivate var childAddedHandle: DatabaseHandle = 0
    fileprivate var childChangedHandle: DatabaseHandle = 0
    fileprivate var childMovedHandle: DatabaseHandle = 0
    fileprivate var childRemovedHandle: DatabaseHandle = 0
    fileprivate var valueHandle: DatabaseHandle = 0
    
    /// A value that associates a call to `performFetch` with the data returned for that fetch.
    fileprivate var currentFetchHandle = 0
    
    /// The batching controller for the current fetch request.
    fileprivate var batchingController: BatchingController!
    
    /// The current fetch results state.
    fileprivate var currentFetchResult: FetchResult!
    
    
    // MARK: - Lifecycle
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
    
    
    // MARK: - Public
    /// Executes the fetch described by the fetch request. You must call this method to start fetching the initial data and to setup
    /// the query observers. If you change the sort decriptors or predicate on the fetch request, you must call this method to
    /// reconfigure the receiver for the updated fetch request.
    public func performFetch() {
        // detach exitsting observers
        unregisterQueryObservers()
        
        // increment the fetch handle
        currentFetchHandle += 1
        
        // update the state
        state = .loading
        
        // create a new batching controller for this fetch
        batchingController = BatchingController()
        batchingController.delegate = self
        
        // update the active fetch request (specifically, we are interested in capture the state of the predicate and sort descriptors is what we are interested in here, since the query can't change)
        let activeFetchRequest = fetchRequest.copy() as! FirebaseFetchRequest
        
        // reset the fetch result
        currentFetchResult = FetchResult(fetchRequest: activeFetchRequest, sectionNameKeyPath: sectionNameKeyPath)
        
        // attach new observers
        registerQueryObservers()
    }
    
    /// Returns the snapshot at a given indexPath.
    ///
    /// - parameters:
    ///     - indexPath: An index path in the fetch results. If indexPath does not describe a valid index path in the fetch results, an error is thrown.
    ///
    /// - returns: The object at a given index path in the fetch results.
    public func object(at indexPath: IndexPath) throws -> DataSnapshot {
        if indexPath.section < sections.count {
            let section = sections[indexPath.section]
            
            if indexPath.row < section.numberOfObjects {
                return section.objects[indexPath.row]
            }
        }
        
        throw FirebaseResultsControllerError.invalidIndexPath(row: indexPath.row, section: indexPath.section)
    }
    
    /// Returns the indexPath of a given snapshot.
    ///
    /// - parameters:
    ///     - snapshot: An object in the receiver’s fetch results.
    ///
    /// - returns: The index path of object in the receiver’s fetch results, or nil if object could not be found.
    public func indexPath(for snapshot: DataSnapshot) -> IndexPath? {
        return sections.lookup(snapshot: snapshot)?.path
    }
    
}

fileprivate extension FirebaseResultsController {
    func unregisterQueryObservers() {
        fetchRequest.query.removeObserver(withHandle: childAddedHandle)
        fetchRequest.query.removeObserver(withHandle: childChangedHandle)
        fetchRequest.query.removeObserver(withHandle: childMovedHandle)
        fetchRequest.query.removeObserver(withHandle: childRemovedHandle)
        fetchRequest.query.removeObserver(withHandle: valueHandle)
    }
    
    func registerQueryObservers() {
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
                strongSelf.handle(updated: snapshot)
            }
        })
        
        childMovedHandle = fetchRequest.query.observe(.childMoved, with: { [weak self] (snapshot) in
            guard let strongSelf = self else {
                return
            }
            
            if handle == strongSelf.currentFetchHandle {
                strongSelf.handle(updated: snapshot)
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
                
                // process batch as soon as all the data is available
                strongSelf.batchingController.processBatch()
            }
        })
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

extension FirebaseResultsController: BatchingControllerDelegate {
    func controllerWillBeginBatchingChanges(_ controller: BatchingController) {
        delegate?.controllerWillChangeContent(self)
    }
    
    func controller(_ controller: BatchingController, finishedBatchingWithInserted inserted: Set<DataSnapshot>, changed: Set<DataSnapshot>, removed: Set<DataSnapshot>) {
        // update the state
        state = .loaded
        
        // create a copy of the current fetch results
        let pendingFetchResult = FetchResult(fetchResult: currentFetchResult)
        
        // apply the changes to the pending results
        pendingFetchResult.apply(inserted: Array(inserted), updated: Array(changed), deleted: Array(removed))
        
        // first compute the diff between the current and the new fetch results
        let diff = FetchResultChanges(fromResult: currentFetchResult, toResult: pendingFetchResult, changedObjects: Array(changed))
        
        // apply the new results
        currentFetchResult = pendingFetchResult
        
        // notify the change tracker of the diff
        changeTracker?.controller(self, didChangeContentWith: diff)
        
        // notify the delegate
        delegate?.controllerDidChangeContent(self)
    }
}

fileprivate extension FirebaseResultsController {
    func handle(inserted: DataSnapshot) {
        batchingController.insert(inserted)
    }
    
    func handle(updated: DataSnapshot) {
        batchingController.update(updated)
    }
    
    func handle(removed: DataSnapshot) {
        batchingController.remove(removed)
    }
}
