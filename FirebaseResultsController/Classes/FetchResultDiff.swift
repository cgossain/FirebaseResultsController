//
//  FetchResultDiff.swift
//  Pods
//
//  Created by Christian Gossain on 2017-02-17.
//
//

import Foundation
import FirebaseDatabase
import Dwifft


public struct FetchResultDiff {
    
    /// This would be `nil` on the initial fetch.
    let fetchResultBeforeChanges: FetchResult
    
    /// The fetch result after applying the changes.
    let fetchResultAfterChanges: FetchResult
    
    /// The inserted items.
    public fileprivate(set) var insertedObjects: [FIRDataSnapshot]?

    /// The indexes of the inserted sections, relative to the 'before' state, after deletions have been applied.
    public fileprivate(set) var insertedSections: IndexSet?
    
    /// The index paths of the inserted rows, relative to the 'before' state, after deletions have been applied.
    public fileprivate(set) var insertedRows: [IndexPath]?

    /// The changed items.
    public fileprivate(set) var changedObjects: [FIRDataSnapshot]?

    /// The indexes of the changed items, relative to the 'before' state.
    public fileprivate(set) var changedIndexes: IndexSet?

    /// The removed items.
    public fileprivate(set) var removedObjects: [FIRDataSnapshot]?

    /// The indexes of the removed sections, relative to the 'before' state.
    public fileprivate(set) var removedSections: IndexSet?
    
    /// The index paths of the removed rows, relative to the 'before' state.
    public fileprivate(set) var removedRows: [IndexPath]?
    
    
    // MARK: - Initilization
    
    init(from fromResult: FetchResult, to toResult: FetchResult) {
        fetchResultBeforeChanges = fromResult
        fetchResultAfterChanges = toResult
        
        // compute the diff
        let sectionsDiff = fetchResultBeforeChanges.sectionKeyValues.diff(fetchResultAfterChanges.sectionKeyValues)
        let rowsDiff = fetchResultBeforeChanges.results.diff(fetchResultAfterChanges.results)
        
        
        // get inserted sections
        var insertedSections = IndexSet()
        for inserted in sectionsDiff.insertions {
            insertedSections.insert(inserted.idx)
        }
        self.insertedSections = insertedSections
        
        
        // get removed sections
        var removedSections = IndexSet()
        for removed in sectionsDiff.deletions {
            removedSections.insert(removed.idx)
        }
        self.removedSections = removedSections
        
        
        // get inserted rows
        var insertedRows: [IndexPath] = []
        for inserted in rowsDiff.insertions {
            // convert the overall index to the appropriate section
            guard let sectionIdx = fetchResultAfterChanges.sectionIndex(for: inserted.value) else {
                continue
            }
            
            guard let sectionOffset = fetchResultAfterChanges.sectionOffset(for: inserted.value) else {
                continue
            }
            
            let rowIdx = inserted.idx - sectionOffset
            insertedRows.append(IndexPath(row: rowIdx, section: sectionIdx))
        }
        self.insertedRows = insertedRows
        
        // get changed rows
        
        
        
        
        // get deleted rows
        var removedRows: [IndexPath] = []
        for removed in rowsDiff.deletions {
            // convert the overall index to the appropriate section
            guard let sectionIdx = fetchResultBeforeChanges.sectionIndex(for: removed.value) else {
                continue
            }
            
            guard let sectionOffset = fetchResultBeforeChanges.sectionOffset(for: removed.value) else {
                continue
            }
            
            let rowIdx = removed.idx - sectionOffset
            removedRows.append(IndexPath(row: rowIdx, section: sectionIdx))
        }
        self.removedRows = removedRows
        
        
//        print("\n")
//        print("Inserted Sections: \(insertedSections)")
//        print("Inserted Rows: \(insertedRows)")
//        print("\n")
//        print("Removed Sections: \(removedSections)")
//        print("Removed Rows: \(removedRows)")
//        print("\n")
    }
    
}
