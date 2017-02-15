//
//  DiffController.swift
//  Pods
//
//  Created by Christian Gossain on 2017-02-13.
//
//

import Foundation
import FirebaseDatabase

/// This controller tracks the "diff" between an initial array of sections, and the reported changes. Use the results to fire appropriate UI notifications (i.e. UITableView).
class DiffController {
    
    struct RowDiff {
        let change: FirebaseResultsController.ChangeType
        let indexPath: IndexPath?
        let newindexPath: IndexPath?
        let object: FIRDataSnapshot
    }
    
    struct SectionDiff {
        let change: FirebaseResultsController.ChangeType
        let sectionIndex: Int
        let section: Section
    }
    
//    /// The fetch request that contains the predicate and sort descriptors used to fetch and arrange the data.
//    let fetchRequest: FirebaseFetchRequest
//    
//    /// The keyPath on the fetched objects used to determine the section they belong to.
//    let sectionNameKeyPath: String?
//    
//    /// The state of the controller sections before the update.
//    let sectionsBeforeChanges: [Section]
//    
//    /// The inserted items.
//    let inserted: [FIRDataSnapshot]?
//    
//    /// The indexes of the inserted items, relative to the 'before' state, after deletions have been applied.
//    private(set) var insertedIndexes: IndexSet?
//    
//    /// The updated items.
//    let updated: [FIRDataSnapshot]?
//    
//    /// The indexes of the changed items, relative to the 'before' state.
//    private(set) var changedIndexes: IndexSet?
//    
//    /// The removed items.
//    let removed: [FIRDataSnapshot]?
//    
//    /// The state of the controller sections after any updates.
//    private(set) var sectionsAfterChanges: [Section] = []
//    
//    /// The indexes of the removed items, relative to the 'before' state.
//    private(set) var removedIndexes: IndexSet?
    
    
    
    
    
    
    
    
    
    // MARK: - Lifecycle
    
//    init(fetchRequest: FirebaseFetchRequest, sectionNameKeyPath: String?, sectionsBeforeChanges: [Section]) {
//        self.fetchRequest = fetchRequest
//        self.sectionNameKeyPath = sectionNameKeyPath
//        self.sectionsBeforeChanges = sectionsBeforeChanges
//    }
    
//    /// Computes the diff that results from applying the given changes to the `before` sections state.
//    func diff(inserted: [FIRDataSnapshot], updated: [FIRDataSnapshot], removed: [FIRDataSnapshot]) {
//        // create a copy of the original sections to be modified
//        sectionsAfterChanges = sectionsBeforeChanges.flatMap({ $0.copy() as? Section })
//        
//        // apply the removed snapshots first
//        
//        
//        
//        
//        
//        
//        
//        
//        
//    }
    
    
//    /// Inserts the snapshot into the sections state and keeps track of the diff.
//    func insert(snapshot: FIRDataSnapshot) {
//        let sectionKeyValue = self.sectionKeyValue(for: snapshot)
//        if let lookupResult = mutableSectionsAfterChanges.lookup(sectionKeyValue: sectionKeyValue) {
//            let section = lookupResult.section
//            
//            // add the snapshot to the section
//            let rowIdx = section.insert(snapshot: snapshot)
//            
//            // return a row diff
//            let insertionIndexPath = IndexPath(row: rowIdx, section: lookupResult.sectionIndex)
//            let diff = RowDiff(change: .insert, indexPath: nil, newindexPath: insertionIndexPath, object: snapshot)
//            rowDiffs.append(diff)
//        }
//        else {
//            // create a new section for this snapshot
//            let section = Section(sectionKeyValue: sectionKeyValue, sortDescriptors: fetchRequest.sortDescriptors)
//            
//            // add the section
//            let sectionIndex = mutableSectionsAfterChanges.insertionIndex(of: section) { $0.sectionKeyValue < $1.sectionKeyValue }
//            mutableSectionsAfterChanges.insert(section, at: sectionIndex)
//            
//            // add the snapshot to the section
//            section.insert(snapshot: snapshot)
//            
//            // return a section diff
//            let diff = SectionDiff(change: .insert, sectionIndex: sectionIndex, section: section)
//            sectionDiffs.append(diff)
//        }
//    }
//    
//    /// Updates the snapshot in the sections state and keeps track of the diff.
//    func update(snapshot: FIRDataSnapshot) {
//        
//        
//        
//        
//        
//    }
//    
    
    
//    /// Removes the snapshot from the sections state and keeps track of the diff.
//    fileprivate func insert(snapshots: [FIRDataSnapshot]) -> (sectionDiffs: [SectionDiff], rowDiffs: [RowDiff]) {
//        var rowDiffs: [RowDiff] = []
//        var sectionDiffs: [SectionDiff] = []
//        
//        // compute all the row and sections diffs
//        for snapshot in snapshots {
//            guard let after = sectionsAfterChanges.lookup(snapshot: snapshot) else {
//                continue
//            }
//            
//            // if there are no more row, this section should be removed
//            if after.section.numberOfObjects == 0 {
//                // remove the entire section
//                sectionsAfterChanges.remove(at: before.path.section)
//                
//                // return a section diff (delete index if relative to the `before` state)
//                let diff = SectionDiff(change: .delete, sectionIndex: before.path.section, section: before.section)
//                sectionDiffs.append(diff)
//            }
//            else if let removedIdx = before.section.indexOf(snapshot: snapshot) {
//                // the section still has objects, but a row was removed
//                let deletionIndexPath = IndexPath(row: removedIdx, section: before.path.section)
//                let diff = RowDiff(change: .delete, indexPath: deletionIndexPath, newindexPath: nil, object: snapshot)
//                rowDiffs.append(diff)
//            }
//            
//            
//            
//            
//            
//            
//            
//            let sectionKeyValue = self.sectionKeyValue(for: snapshot)
//            if let after = sectionsAfterChanges.lookup(sectionKeyValue: sectionKeyValue) {                
//                // add the snapshot to the section
//                let rowIdx = after.section.insert(snapshot: snapshot)
//                
//                // return a row diff
//                let insertionIndexPath = IndexPath(row: rowIdx, section: lookupResult.sectionIndex)
//                return RowDiff(type: .insert, object: snapshot, indexPath: nil, newIndexPath: insertionIndexPath)
//            }
//            else {
//                // create a new section for this snapshot
//                let section = MFTFirebaseResultsSection(sectionKeyValue: sectionKeyValue, sortDescriptors: activeFetchRequest?.sortDescriptors)
//                
//                // add the section
//                let sectionIdx = mutableSections.insertionIndexOf(elem: section) { $0.sectionKeyValue < $1.sectionKeyValue }
//                mutableSections.insert(section, at: sectionIdx)
//                
//                // add the snapshot to the section
//                section.insert(snapshot: snapshot)
//                
//                // return a section diff
//                return SectionDiff(type: .insert, section: section, sectionIndex: sectionIdx)
//            }
//        }
//        
//        
//        
//        
//        
//        
//    }
//    
//    /// Removes the snapshot from the sections state and keeps track of the diff.
//    fileprivate func remove(snapshots: [FIRDataSnapshot]) -> (sectionDiffs: [SectionDiff], rowDiffs: [RowDiff]) {
//        var rowDiffs: [RowDiff] = []
//        var sectionDiffs: [SectionDiff] = []
//        
//        // compute all the row and sections diffs
//        for snapshot in snapshots {
//            guard let before = sectionsBeforeChanges.lookup(snapshot: snapshot), let after = sectionsAfterChanges.lookup(snapshot: snapshot) else {
//                continue
//            }
//            
//            // remove the snapshot from the `after` state
//            after.section.remove(snapshot: snapshot)
//            
//            // if there are no more row, this section should be removed
//            if after.section.numberOfObjects == 0 {
//                // remove the entire section
//                sectionsAfterChanges.remove(at: before.path.section)
//                
//                // return a section diff (delete index if relative to the `before` state)
//                let diff = SectionDiff(change: .delete, sectionIndex: before.path.section, section: before.section)
//                sectionDiffs.append(diff)
//            }
//            else if let removedIdx = before.section.indexOf(snapshot: snapshot) {
//                // the section still has objects, but a row was removed
//                let deletionIndexPath = IndexPath(row: removedIdx, section: before.path.section)
//                let diff = RowDiff(change: .delete, indexPath: deletionIndexPath, newindexPath: nil, object: snapshot)
//                rowDiffs.append(diff)
//            }
//        }
//    }
    
}

extension DiffController {
    
//    fileprivate func sectionKeyValue(for snapshot: FIRDataSnapshot) -> String {
//        if let sectionNameKeyPath = sectionNameKeyPath, let obj = snapshot.value as? AnyObject, let value = obj.value(forKeyPath: sectionNameKeyPath) as? AnyObject {
//            return String(describing: value)
//        }
//        
//        return "" // name of the `nil` section
//    }
//    
//    fileprivate enum EffectiveChangeType {
//        case insert
//        case change
//        case remove
//        case ignore
//    }
//    
//    /// Determines whether the given snapshot from a change notification can be reassigned as an insert or removal, or if it should remain a change.
//    fileprivate func effectiveChangeType(for snapshot: FIRDataSnapshot) -> EffectiveChangeType {
//        let canInclude = self.canInclude(snapshot: snapshot)
//        let currentlyExists = sectionsBeforeChanges.contains(snapshot: snapshot)
//        
//        
//        if canInclude && !currentlyExists {
//            // the snapshot can now be included in our data set, but does not currently exist
//            // this indicates that the snapshot has changed such that is can now be included
//            // and is therefore, effectively an insertion
//            return .insert
//        }
//        else if !canInclude && currentlyExists {
//            // the snapshot can not be included in our data set, but currently exist
//            // this indicates that the snapshot has changed such that is can no longer be included
//            // and is therefore, effectively a removal
//            return .remove
//        }
//        else if canInclude {
//            return .change
//        }
//        else {
//            return .ignore
//        }
//    }
//    
//    /// Returns true if the given snapshot should be included in the data set.
//    fileprivate func canInclude(snapshot: FIRDataSnapshot) -> Bool {
//        if let predicate = fetchRequest.predicate {
//            return predicate.evaluate(with: snapshot.value)
//        }
//        return true
//    }
//    
//    /// Returns true if the incoming snapshot (from a change notification or batching mechanism) can be ignored.
//    /// Specifically, this method checks two things:
//    ///     1. Does the snapshot evaluate against the active predicate.
//    ///     2. Does the snapshot exist in the current sections state.
//    ///
//    /// If both conditions above are false, then the change will have no effect on the sections state and therefore can be ignored.
//    /// Note that if the `newContent` flag is true, then only the first condition is evaluated. The idea being that this is a new fetch
//    /// and there are no items in the data set currently.
//    fileprivate func shouldIgnore(snapshot: FIRDataSnapshot, initialFetch: Bool = false) -> Bool {
//        // for efficiency, if we know that we are loading the inital data, we can assume that the snapshot is not currently contained in the sections data
//        if initialFetch {
//            return !canInclude(snapshot: snapshot)
//        }
//        return !canInclude(snapshot: snapshot) && !sectionsBeforeChanges.contains(snapshot: snapshot)
//    }
    
}
