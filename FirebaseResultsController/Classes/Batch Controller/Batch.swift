//
//  Batch.swift
//  FirebaseResultsController
//
//  Created by Christian Gossain on 2020-01-13.
//

import Foundation
import FirebaseDatabase

/// An object used to track a batch of changes together.
class Batch {
    struct Result {
        let inserted: [String: DataSnapshot]
        let changed: [String: DataSnapshot]
        let removed: [String: DataSnapshot]
    }
    
    /// A unique identifier for this batch.
    let identifier = UUID().uuidString
    
    
    // MARK: - Private Properties
    private var rawInserted: [String: DataSnapshot] = [:]
    private var rawChanged: [String: DataSnapshot] = [:]
    private var rawRemoved: [String: DataSnapshot] = [:]
    
    
    // MARK: - Lifecycle
    func insert(_ snapshot: DataSnapshot) {
        let key = snapshot.ref.description
        rawInserted[key] = snapshot
    }
    
    func update(_ snapshot: DataSnapshot) {
        let key = snapshot.ref.description
        rawChanged[key] = snapshot
    }
    
    func remove(_ snapshot: DataSnapshot) {
        let key = snapshot.ref.description
        rawRemoved[key] = snapshot
    }
    
    func flush() -> Result {
        // create copies of the raw data
        var inserted = rawInserted
        var changed = rawChanged
        var removed = rawRemoved
        
        // cleanup redundancies
        for (key, snapshot) in rawInserted {
            if rawChanged[key] != nil {
                // replace the existing `inserted` version with the `changed` version
                inserted[key] = snapshot
                
                // remove from the `changed` version
                changed[key] = nil
            }
            else if rawRemoved[key] != nil {
                // the same snapshot was both inserted and removed
                // in the same batch (i.e. no net change)
                inserted[key] = nil
                removed[key] = nil
            }
        }
        
        return Result(inserted: inserted, changed: changed, removed: removed)
    }
}
