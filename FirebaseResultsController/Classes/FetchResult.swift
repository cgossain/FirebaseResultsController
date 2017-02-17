//
//  FetchResult.swift
//  Pods
//
//  Created by Christian Gossain on 2017-02-14.
//
//

import Foundation
import FirebaseDatabase


private let FetchResultNilSectionName = "" // the name of the `nil` section

class FetchResult {
    
    /// The FirebaseFetchRequest instance used to do the fetching. The sort descriptor used in the request groups objects into sections.
    let fetchRequest: FirebaseFetchRequest
    
    /// The keyPath on the fetched objects used to determine the section they belong to.
    let sectionNameKeyPath: String?
    
    /// The current fetch results ordered by section first (if a `sectionNameKeyPath` was provided), then by the fetch request sort descriptors.
    fileprivate(set) var results: [FIRDataSnapshot] = []
    
    /// An array containing the name of each section that exists in the results. The order of the items in this list represent the order that the sections should appear.
    /// -note: If the `sectionNameKeyPath` value is `nil`, a single section will be generated.
    var sectionKeyValues: [String] {
        return Array(sectionsBySectionKeyValue.keys).sorted(by: <)
    }
    
    /// The fetch results as arranged sections.
    var sections: [Section] {
        if let sections = _sections {
            return sections
        }
        
        // compute the sections array
        let computed = Array(sectionsBySectionKeyValue.values).sorted(by: { $0.sectionKeyValue < $1.sectionKeyValue })
        _sections = computed
        return computed
    }
    fileprivate var _sections: [Section]? // hold the current non-stale sections array
    
    /// A dictionary that maps the current sections to their sectionKeyValue.
    fileprivate(set) var sectionsBySectionKeyValue: [String: Section] = [:]
    
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
    
    /// Creates a new FetchResult object, initialized with the contents of an existing FetchResult object.
    convenience init(fetchResult: FetchResult) {
        self.init(fetchRequest: fetchResult.fetchRequest, sectionNameKeyPath: fetchResult.sectionNameKeyPath)
        results.append(contentsOf: fetchResult.results)
        
        // copy the section objects; we don't want to affect the original fetch results sections when we make changes here
        var copiedSectionsBySectionKeyValue: [String: Section] = [:]
        for (sectionKeyValue, section) in fetchResult.sectionsBySectionKeyValue {
            copiedSectionsBySectionKeyValue[sectionKeyValue] = section.copy() as? Section
        }
        sectionsBySectionKeyValue = copiedSectionsBySectionKeyValue
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
        
        // reset the sections array since the data has changed
        _sections = nil
    }
    
}

extension FetchResult {
    
    /// Adds the snapshot to the results at the correct position, and if it evaluates against the fetch request predicate.
    func insert(snapshot: FIRDataSnapshot) {
        // return early if the inserted snapshot does not evaluate against our predicate
        if !canInclude(snapshot: snapshot) {
            return
        }
        
        // compute the insertion index that maintains the sort order
        let idx = results.insertionIndex(of: snapshot, using: fetchSortDescriptors)
        
        // insert at the insertion index
        results.insert(snapshot, at: idx)
        
        // create/update the section
        let sectionKeyValue = snapshot.sectionKeyValue(forSectionNameKeyPath: sectionNameKeyPath)
        let section = sectionsBySectionKeyValue[sectionKeyValue] ?? Section(sectionKeyValue: sectionKeyValue, sortDescriptors: fetchRequest.sortDescriptors)
        section.insert(snapshot: snapshot)
        sectionsBySectionKeyValue[sectionKeyValue] = section
    }
    
    /// Removes the snapshot if it exists in the results.
    func delete(snapshot: FIRDataSnapshot) {
        guard let idx = results.index(where: { $0.key == snapshot.key }) else {
            return
        }
        
        // remove the snapshot
        results.remove(at: idx)
        
        // update/remove the section
        let sectionKeyValue = snapshot.sectionKeyValue(forSectionNameKeyPath: sectionNameKeyPath)
        let section = sectionsBySectionKeyValue[sectionKeyValue]! // force unwrap; there is something wrong at this point if the force unwrap does not work (since it exists in the `results` array)
        section.remove(snapshot: snapshot)
        sectionsBySectionKeyValue[sectionKeyValue] = section.numberOfObjects < 1 ? nil : section
    }
    
    /// Replaces the existing version of the snapshot with the specified one.
    func update(snapshot: FIRDataSnapshot) {
        delete(snapshot: snapshot)
        insert(snapshot: snapshot)
    }
    
}

extension FetchResult {
    
    /// Specifies all the sort descriptors that should be used when inserting snapshots (including the `sectionNameKeyPath`).
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
    
    /// Extracts the section key value of the givent snapshot.
    fileprivate func sectionKeyValue(of snapshot: FIRDataSnapshot) -> String {
        return snapshot.sectionKeyValue(forSectionNameKeyPath: self.sectionNameKeyPath)
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
    
    /// Extracts the section key value for the given key path.
    fileprivate func sectionKeyValue(forSectionNameKeyPath sectionNameKeyPath: String?) -> String {
        if let sectionNameKeyPath = sectionNameKeyPath, let obj = self.value as? AnyObject, let value = obj.value(forKeyPath: sectionNameKeyPath) as? AnyObject {
            return String(describing: value)
        }
        return FetchResultNilSectionName
    }
    
}