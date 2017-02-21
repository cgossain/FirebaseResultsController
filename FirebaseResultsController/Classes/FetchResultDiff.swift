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
    
    /// The removed items.
    public fileprivate(set) var removedObjects: [FIRDataSnapshot]?
    
    /// The indexes of the removed sections, relative to the 'before' state.
    public fileprivate(set) var removedSections: IndexSet?
    
    /// The index paths of the removed rows, relative to the 'before' state.
    public fileprivate(set) var removedRows: [IndexPath]?
    
    /// The moved items.
    public fileprivate(set) var movedObjects: [FIRDataSnapshot]?
    
    /// The index paths of the moved rows.
    public fileprivate(set) var movedRows: [(from: IndexPath, to: IndexPath)]?
    
    /// The changed items.
    public fileprivate(set) var changedObjects: [FIRDataSnapshot]?

    /// The index paths of the changed rows, relative to the 'before' state.
    public fileprivate(set) var changedRows: [IndexPath]?
    
    
    // MARK: - Initilization
    
    /// Creates a diff between two fetch result objects.
    init(from fromResult: FetchResult, to toResult: FetchResult, changedObjects: [FIRDataSnapshot]) {
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
        
        
        // extract the moves from the rows diff
        var deletions = rowsDiff.deletions
        var insertions = rowsDiff.insertions
        var moves: [(from: DiffStep<FIRDataSnapshot>, to: DiffStep<FIRDataSnapshot>)] = []
        
        // moves will be the diffs that appear both as deletions and insertions
        for deletion in deletions {
            if let insertion = insertions.filter({ $0.value.key == deletion.value.key }).first {
                moves.append((from: deletion, to: insertion))
            }
        }
        
        for move in moves {
            // remove the deletions that will be handled in the move
            if let idx = deletions.index(where: { $0.value.key == move.from.value.key }) {
                deletions.remove(at: idx)
            }
            
            // remove the insertion that will be handled in the move
            if let idx = insertions.index(where: { $0.value.key == move.to.value.key }) {
                insertions.remove(at: idx)
            }
        }
        
        // get inserted rows
        var insertedObjects: [FIRDataSnapshot] = []
        var insertedRows: [IndexPath] = []
        for inserted in insertions {
            // convert the overall index to the appropriate section
            guard let sectionIdx = fetchResultAfterChanges.sectionIndex(for: inserted.value) else {
                continue
            }
            
            guard let sectionOffset = fetchResultAfterChanges.sectionOffset(for: inserted.value) else {
                continue
            }
            
            insertedObjects.append(inserted.value)
            
            // calculate the index path
            let rowIdx = inserted.idx - sectionOffset
            insertedRows.append(IndexPath(row: rowIdx, section: sectionIdx))
        }
        self.insertedObjects = insertedObjects
        self.insertedRows = insertedRows
        
        
        // get deleted rows
        var removedObjects: [FIRDataSnapshot] = []
        var removedRows: [IndexPath] = []
        for removed in deletions {
            // convert the overall index to the appropriate section
            guard let sectionIdx = fetchResultBeforeChanges.sectionIndex(for: removed.value) else {
                continue
            }
            
            guard let sectionOffset = fetchResultBeforeChanges.sectionOffset(for: removed.value) else {
                continue
            }
            
            removedObjects.append(removed.value)
            
            // calculate the index path
            let rowIdx = removed.idx - sectionOffset
            removedRows.append(IndexPath(row: rowIdx, section: sectionIdx))
        }
        self.removedObjects = removedObjects
        self.removedRows = removedRows
        
        
        // get moved rows
        var movedObjects: [FIRDataSnapshot] = []
        var movedRows: [(from: IndexPath, to: IndexPath)] = []
        for move in moves {
            guard let fromSectionIdx = fetchResultBeforeChanges.sectionIndex(for: move.from.value) else {
                continue
            }
            
            guard let fromSectionOffset = fetchResultBeforeChanges.sectionOffset(for: move.from.value) else {
                continue
            }
            
            guard let toSectionIdx = fetchResultAfterChanges.sectionIndex(for: move.to.value) else {
                continue
            }
            
            guard let toSectionOffset = fetchResultAfterChanges.sectionOffset(for: move.to.value) else {
                continue
            }
            
            movedObjects.append(move.to.value)
            
            // calculate the `from` index path
            let fromRowIdx = move.from.idx - fromSectionOffset
            let fromPath = IndexPath(row: fromRowIdx, section: fromSectionIdx)
            
            // calculate the `to` index path
            let toRowIdx = move.to.idx - toSectionOffset
            let toPath = IndexPath(row: toRowIdx, section: toSectionIdx)
            
            movedRows.append((from: fromPath, to: toPath))
        }
        self.movedObjects = movedObjects
        self.movedRows = movedRows
        
        // get changed rows
        var changedRows: [IndexPath] = []
        for changed in changedObjects {
            guard let path = fetchResultBeforeChanges.sections.lookup(snapshot: changed)?.path else {
                continue
            }
            
            changedRows.append(path)
        }
        self.changedObjects = changedObjects
        self.changedRows = changedRows
    }
    
}
