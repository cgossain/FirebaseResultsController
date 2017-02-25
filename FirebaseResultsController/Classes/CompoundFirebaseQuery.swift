//
//  CompoundFirebaseQuery.swift
//  MooveFit
//
//  Created by Christian Gossain on 2017-02-21.
//  Copyright © 2017 Christian Gossain. All rights reserved.
//

import Foundation
import FirebaseDatabase


public protocol CompoundFirebaseQueryDelegate: class {
    
    /// Called when the query will being updating its results due to data being received.
    func queryWillChangeContent(_ query: CompoundFirebaseQuery)
    
    /// Called when the query has updated its fetch results.
    func queryDidChangeContent(_ query: CompoundFirebaseQuery)
    
}

public class CompoundFirebaseQuery {
    
    public weak var delegate: CompoundFirebaseQueryDelegate?
    
    /// Set to true if changes should no be batched, but rather processed as soon as they are received.
    public var processesChangesImmediately = false {
        didSet {
            batchingController.processesChangesImmediately = processesChangesImmediately
        }
    }
    
    fileprivate var queriesByIdentifier: [String: FIRDatabaseQuery] = [:]
    
    fileprivate var handlesByIdentifier: [String: FIRDatabaseHandle] = [:]
    
    fileprivate var resultsByIdentifier: [String: FIRDataSnapshot] = [:]
    
    fileprivate lazy var batchingController: BatchingController = {
        let controller = BatchingController()
        controller.delegate = self
        controller.processesChangesImmediately = self.processesChangesImmediately
        return controller
    }()
    
    // MARK: - Lifecycle
    
    deinit {
        unregisterQueryObservers()
    }
    
    // MARK: - Public
    
    /// Adds a query to be fetched.
    public func add(query: FIRDatabaseQuery, forIdentifier identifier: String) {
        queriesByIdentifier[identifier] = query
    }
    
    /// Begins fetching all added queries. If you add more queries, this method should be called again.
    public func performFetch() {
        unregisterQueryObservers()
        
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
                strongSelf.batchingController.change(snapshot: snapshot)
            })
        }
    }
    
    /// Returns the result of the query associated with the given identifier.
    public func result(forIdentifier identifier: String) -> FIRDataSnapshot? {
        return resultsByIdentifier[identifier]
    }
    
    // MARK: - Private
    
    fileprivate func unregisterQueryObservers() {
        for (identifer, handle) in handlesByIdentifier {
            if let query = queriesByIdentifier[identifer] {
                query.removeObserver(withHandle: handle)
            }
        }
        
        // cleanup
        handlesByIdentifier.removeAll()
    }
    
}

extension CompoundFirebaseQuery: BatchingControllerDelegate {
    
    func controllerWillBeginBatchingChanges(_ controller: BatchingController) {
        delegate?.queryWillChangeContent(self)
    }
    
    func controller(_ controller: BatchingController, finishedBatchingWithInserted inserted: Set<FIRDataSnapshot>, changed: Set<FIRDataSnapshot>, removed: Set<FIRDataSnapshot>) {
        delegate?.queryDidChangeContent(self)
    }
    
}
