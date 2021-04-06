//
//  FirebaseRealtimeDatabaseStoreConnector.swift
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
import FetchedResultsController
import FirebaseDatabase

extension DataSnapshot: Identifiable {
    public var id: String { return key }
}

final public class FirebaseRealtimeDatabaseFetchRequest: FetchedResultsStoreRequest {
    /// The database query associated with this fetch request.
    public let query: DatabaseQuery
    
    /// Initializes the fetch request with the given FIRDatabaseQuery.
    public init(query: DatabaseQuery) {
        self.query = query
    }
}

final public class FirebaseRealtimeDatabaseStoreConnector: FetchedResultsStoreConnector<FirebaseRealtimeDatabaseFetchRequest, DataSnapshot> {
    // MARK: - Private Properties
    private var childAddedHandle: DatabaseHandle = 0
    private var childChangedHandle: DatabaseHandle = 0
    private var childMovedHandle: DatabaseHandle = 0
    private var childRemovedHandle: DatabaseHandle = 0
    private var valueHandle: DatabaseHandle = 0
    
    /// A value that associates a call to `performFetch` with the data returned for that fetch.
    private var currentFetchHandle = 0
    
    
    // MARK: - PersistentStoreConnector
    override public func execute(_ request: FirebaseRealtimeDatabaseFetchRequest) {
        super.execute(request)
        
        if currentFetchHandle > 0 {
            request.query.removeObserver(withHandle: childAddedHandle)
            request.query.removeObserver(withHandle: childChangedHandle)
            request.query.removeObserver(withHandle: childMovedHandle)
            request.query.removeObserver(withHandle: childRemovedHandle)
            request.query.removeObserver(withHandle: valueHandle)
        }
        
        currentFetchHandle += 1
        let handle = currentFetchHandle
        
        // observe insertions
        childAddedHandle = request.query.observe(.childAdded, with: { [weak self] (snapshot) in
            guard let strongSelf = self else {
                return
            }
            
            if handle == strongSelf.currentFetchHandle {
                strongSelf.enqueue(inserted: snapshot)
            }
        })
        
        // observe changes
        childChangedHandle = request.query.observe(.childChanged, with: { [weak self] (snapshot) in
            guard let strongSelf = self else {
                return
            }
            
            if handle == strongSelf.currentFetchHandle {
                strongSelf.enqueue(updated: snapshot)
            }
        })
        
        // observe moves
        childMovedHandle = request.query.observe(.childMoved, with: { [weak self] (snapshot) in
            guard let strongSelf = self else {
                return
            }
            
            if handle == strongSelf.currentFetchHandle {
                strongSelf.enqueue(updated: snapshot)
            }
        })
        
        // observe deletions
        childRemovedHandle = request.query.observe(.childRemoved, with: { [weak self] (snapshot) in
            guard let strongSelf = self else {
                return
            }
            
            if handle == strongSelf.currentFetchHandle {
                strongSelf.enqueue(removed: snapshot)
            }
        })
        
        // observe entire node updated
        valueHandle = request.query.observe(.value, with: { [weak self] (snapshot) in
            guard let strongSelf = self else {
                return
            }

            // when this observer fires we know the entire database node has loaded
            // therefore to minimize any delays in the UI updating we can trigger
            // the processing of any enqueued changes immediately at this point
            // process batch as soon as all the data is available
            if handle == strongSelf.currentFetchHandle {
                strongSelf.processPendingChanges()
            }
        })
    }
}
