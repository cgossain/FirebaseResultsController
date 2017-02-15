//
//  FetchResults.swift
//  Pods
//
//  Created by Christian Gossain on 2017-02-14.
//
//

import Foundation
import FirebaseDatabase


class FetchResults {
    
    /// The FirebaseFetchRequest instance used to do the fetching. The sort descriptor used in the request groups objects into sections.
    let fetchRequest: FirebaseFetchRequest
    
    /// The keyPath on the fetched objects used to determine the section they belong to.
    let sectionNameKeyPath: String?
    
    /// The current fetch results ordered by section first (if a `sectionNameKeyPath` was provided), then by the fetch request sort descriptors.
    fileprivate(set) var results: [FIRDataSnapshot] = []
    
    /// An array representing the sorted section names of all sections contained in the results.
    /// -note: If the `sectionNameKeyPath` value is `nil`, a single section will be generated.
    fileprivate(set) var sectionKeyValues: [String] = []
    
    /// Initializes a new fetch results objects with the given `fetchRequest` and `sectionNameKeyPath`. These are used to 
    /// filter and order results as snapshots are inserted and removed.
    ///
    /// - parameters:
    ///   - fetchRequest: The fetch request used to retrieve the results.
    ///   - sectionNameKeyPath: The key path on result objects that represents the section name.
    init(fetchRequest: FirebaseFetchRequest, sectionNameKeyPath: String?) {
        self.fetchRequest = fetchRequest
        self.sectionNameKeyPath = sectionNameKeyPath
    }
    
    /// Creates a new FetchResults object, initialized with the contents of an existing FetchResults object.
    convenience init(fetchResults: FetchResults) {
        self.init(fetchRequest: fetchResults.fetchRequest, sectionNameKeyPath: fetchResults.sectionNameKeyPath)
        results.append(contentsOf: fetchResults.results)
        sectionKeyValues = fetchResults.sectionKeyValues
    }
    
    /// Applies the given changes to the current results.
    func apply(inserted: [FIRDataSnapshot], updated: [FIRDataSnapshot], deleted: [FIRDataSnapshot]) {
        
        // apply insertions
        for snapshot in inserted {
            insert(snapshot: snapshot)
        }
        
        // apply updates
        for snapshot in updated {
            update(snapshot: snapshot)
        }
        
        // apply deletiona
        for snapshot in deleted {
            delete(snapshot: snapshot)
        }
        
    }
    
}

extension FetchResults {
    
    /// Adds the snapshot to the results at the correct position, and if it evaluates against the fetch request predicate.
    func insert(snapshot: FIRDataSnapshot) {
        // return early if the inserted snapshot does not evaluate against our predicate
        if !canInclude(snapshot: snapshot) {
            return
        }
        
        // compute the insertion index that maintains the sort order
        let idx = results.insertionIndex(of: snapshot, isOrderedBefore: {
            var result: ComparisonResult = .orderedAscending
            for descriptor in fetchSortDescriptors {
                result = descriptor.compare($0.value, to: $1.value)
                
                if result != .orderedSame {
                    break
                }
            }
            
            // if `orderedAscending`, the first element is ordered before the second element
            return (result == .orderedAscending)
        })
        
        // insert at the insertion index
        results.insert(snapshot, at: idx)
    }
    
    /// Removes the snapshot if it exists in the results.
    func delete(snapshot: FIRDataSnapshot) {
        guard let idx = results.index(where: { $0.key == snapshot.key }) else {
            return
        }
        
        results.remove(at: idx)
    }
    
    /// Replaces the existing version of the snapshot with the specified one.
    func update(snapshot: FIRDataSnapshot) {
        delete(snapshot: snapshot)
        insert(snapshot: snapshot)
    }
    
}

extension FetchResults {
    
    fileprivate var fetchSortDescriptors: [NSSortDescriptor] {
        var descriptors = [NSSortDescriptor]()
        
        // sort by the sections first
        if let sectionNameKeyPath = sectionNameKeyPath {
            descriptors.append(NSSortDescriptor(key: sectionNameKeyPath, ascending: true))
        }
        
        // then add the custom sort descriptors
        if let sortDescriptors = fetchRequest.sortDescriptors {
            descriptors.append(contentsOf: sortDescriptors)
        }
        
        return descriptors
    }
    
    fileprivate func sectionKeyValue(of snapshot: FIRDataSnapshot) -> String {
        return snapshot.sectionKeyValue(forSectionNameKeyPath: self.sectionNameKeyPath)
    }
    
    fileprivate enum EffectiveChangeType {
        case insert
        case change
        case remove
        case ignore
    }
    
    /// Determines whether the given snapshot from a change notification can be reassigned as an insert or removal, or if it should remain a change.
    fileprivate func effectiveChangeType(for snapshot: FIRDataSnapshot) -> EffectiveChangeType {
        let canInclude = self.canInclude(snapshot: snapshot)
        let currentlyExists = results.contains(snapshot)
        
        if canInclude && !currentlyExists {
            // the snapshot can now be included in our data set, but does not currently exist
            // this indicates that the snapshot has changed such that is can now be included
            // and is therefore, effectively an insertion
            return .insert
        }
        else if !canInclude && currentlyExists {
            // the snapshot can not be included in our data set, but currently exist
            // this indicates that the snapshot has changed such that is can no longer be included
            // and is therefore, effectively a removal
            return .remove
        }
        else if canInclude {
            return .change
        }
        else {
            return .ignore
        }
    }
    
    /// Returns true if the given snapshot should be included in the data set.
    fileprivate func canInclude(snapshot: FIRDataSnapshot) -> Bool {
        if let predicate = fetchRequest.predicate {
            return predicate.evaluate(with: snapshot.value)
        }
        return true
    }
    
}

extension FIRDataSnapshot {
    
    fileprivate func sectionKeyValue(forSectionNameKeyPath sectionNameKeyPath: String?) -> String {
        if let sectionNameKeyPath = sectionNameKeyPath, let obj = self.value as? AnyObject, let value = obj.value(forKeyPath: sectionNameKeyPath) as? AnyObject {
            return String(describing: value)
        }
        return "" // name of the `nil` section
    }
    
}
