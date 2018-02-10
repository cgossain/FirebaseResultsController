//
//  ComposedFirebaseQuery.swift
//  MooveFit
//
//  Created by Christian Gossain on 2017-02-21.
//  Copyright © 2017 Christian Gossain. All rights reserved.
//

import Foundation
import FirebaseDatabase

public protocol ComposedFirebaseQueryDelegate: class {
    /// Called when the query will being updating its results due to data being received.
    func queryWillChangeContent(_ query: ComposedFirebaseQuery)
    
    /// Called when the query has updated its fetch results.
    func queryDidChangeContent(_ query: ComposedFirebaseQuery)
}

/// The ComposedFirebaseQuery is a simple class where multiple DatabaseQuery instances can be added. When `performFetch()` is called, each individual query is started
/// but the overall delegate is not called until all queries have returned results.
public class ComposedFirebaseQuery {
    
    /// The object that is notified when the query results change.
    public weak var delegate: ComposedFirebaseQueryDelegate?
    
    /// Set to true if changes should not be batched, but rather processed as soon as they are received.
    public var processesChangesImmediately = false {
        didSet {
            batchingController.processesChangesImmediately = processesChangesImmediately
        }
    }
    
    /// The current state of the query.
    public fileprivate(set) var state: FirebaseResultsController.State = .initial
    
    /// An internal map of the added queries, keyed by their identifier.
    fileprivate var queriesByIdentifier: [String: DatabaseQuery] = [:]
    
    /// An internal map of the query observer handles, keyed by their identifier.
    fileprivate var handlesByIdentifier: [String: DatabaseHandle] = [:]
    
    /// An internal map of the query fetch results, keyed by their identifier.
    fileprivate var resultsByIdentifier: [String: DataSnapshot] = [:]
    
    /// The internal batching controller instance.
    fileprivate lazy var batchingController: BatchingController = {
        let controller = BatchingController()
        controller.delegate = self
        controller.processesChangesImmediately = self.processesChangesImmediately
        return controller
    }()
    
    
    // MARK: - Lifecycle
    public init() {
        
    }
    
    deinit {
        unregisterQueryObservers()
    }
    
    
    // MARK: - Public
    
    /// Adds a query to be fetched.
    public func add(query: DatabaseQuery, forIdentifier identifier: String) {
        queriesByIdentifier[identifier] = query
    }
    
    /// Begins fetching all added queries. If you add more queries, this method should be called again.
    public func performFetch() {
        unregisterQueryObservers()
        
        // update the state
        state = .loading
        
        // drop all results
        resultsByIdentifier.removeAll()
        
        // register observers on each query
        for (identifier, query) in queriesByIdentifier {
            handlesByIdentifier[identifier] = query.observe(.value, with: { [weak self] (snapshot) in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.resultsByIdentifier[identifier] = snapshot
                
                // notify the batching controller
                strongSelf.batchingController.update(snapshot)
            })
        }
    }
    
    /// Returns the result of the query associated with the given identifier.
    public func result(forIdentifier identifier: String) -> DataSnapshot? {
        return resultsByIdentifier[identifier]
    }
    
}

fileprivate extension ComposedFirebaseQuery {
    func unregisterQueryObservers() {
        for (identifer, handle) in handlesByIdentifier {
            if let query = queriesByIdentifier[identifer] {
                query.removeObserver(withHandle: handle)
            }
        }
        
        // cleanup
        handlesByIdentifier.removeAll()
    }
}

extension ComposedFirebaseQuery: BatchingControllerDelegate {
    func controllerWillBeginBatchingChanges(_ controller: BatchingController) {
        delegate?.queryWillChangeContent(self)
    }
    
    func controller(_ controller: BatchingController, finishedBatchingWithInserted inserted: Set<DataSnapshot>, changed: Set<DataSnapshot>, removed: Set<DataSnapshot>) {
        // update the state
        state = .loaded
        
        // notify the delegate
        delegate?.queryDidChangeContent(self)
    }
}
