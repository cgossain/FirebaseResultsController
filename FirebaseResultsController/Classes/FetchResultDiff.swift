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

struct SectionDescriptor {
    let idx: Int
    let section: Section
}

struct RowDescriptor {
    let indexPath: IndexPath
    let value: FIRDataSnapshot
}

struct FetchResultDiff {
    
    /// This would be `nil` on the initial fetch.
    let fetchResultBeforeChanges: FetchResult
    
    /// The fetch result after applying the changes.
    let fetchResultAfterChanges: FetchResult
    
    /// The indexes of the removed sections, relative to the 'before' state.
    fileprivate(set) var removedSections: [SectionDescriptor]?
    
    /// The index paths of the removed rows, relative to the 'before' state.
    fileprivate(set) var removedRows: [RowDescriptor]?

    /// The indexes of the inserted sections, relative to the 'before' state, after deletions have been applied.
    fileprivate(set) var insertedSections: [SectionDescriptor]?
    
    /// The index paths of the inserted rows, relative to the 'before' state, after deletions have been applied.
    fileprivate(set) var insertedRows: [RowDescriptor]?
    
    /// The index paths of the moved rows.
    fileprivate(set) var movedRows: [(from: RowDescriptor, to: RowDescriptor)]?
    
    /// The index paths of the changed rows, relative to the 'before' state.
    fileprivate(set) var changedRows: [RowDescriptor]?
    
    // MARK: - Initilization
    
    /// Creates a diff between two fetch result objects.
    init(from fromResult: FetchResult, to toResult: FetchResult, changedObjects: [FIRDataSnapshot]) {
        fetchResultBeforeChanges = fromResult
        fetchResultAfterChanges = toResult
        
        // compute the diff
        let sectionsDiff = fetchResultBeforeChanges.sectionKeyValues.diff(fetchResultAfterChanges.sectionKeyValues)
        let rowsDiff = fetchResultBeforeChanges.results.diff(fetchResultAfterChanges.results)
        
        
        // get removed sections
        var removedSections: [SectionDescriptor] = []
        for removed in sectionsDiff.deletions {
            removedSections.append(SectionDescriptor(idx: removed.idx, section: fetchResultBeforeChanges.sections[removed.idx]))
        }
        self.removedSections = removedSections
        
        
        // get inserted sections
        var insertedSections: [SectionDescriptor] = []
        for inserted in sectionsDiff.insertions {
            insertedSections.append(SectionDescriptor(idx: inserted.idx, section: fetchResultAfterChanges.sections[inserted.idx]))
        }
        self.insertedSections = insertedSections
        
        
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
        var insertedRows: [RowDescriptor] = []
        for inserted in insertions {
            // convert the overall index to the appropriate section
            guard let sectionIdx = fetchResultAfterChanges.sectionIndex(for: inserted.value) else {
                continue
            }
            
            guard let sectionOffset = fetchResultAfterChanges.sectionOffset(for: inserted.value) else {
                continue
            }
            
            // calculate the index path
            let rowIdx = inserted.idx - sectionOffset
            let indexPath = IndexPath(row: rowIdx, section: sectionIdx)
            
            // track the insert
            insertedRows.append(RowDescriptor(indexPath: indexPath, value: inserted.value))
        }
        self.insertedRows = insertedRows
        
        
        // get deleted rows
        var removedRows: [RowDescriptor] = []
        for removed in deletions {
            // convert the overall index to the appropriate section
            guard let sectionIdx = fetchResultBeforeChanges.sectionIndex(for: removed.value) else {
                continue
            }
            
            guard let sectionOffset = fetchResultBeforeChanges.sectionOffset(for: removed.value) else {
                continue
            }
            
            // calculate the index path
            let rowIdx = removed.idx - sectionOffset
            let indexPath = IndexPath(row: rowIdx, section: sectionIdx)
            
            // track the deletion
            removedRows.append(RowDescriptor(indexPath: indexPath, value: removed.value))
        }
        self.removedRows = removedRows
        
        
        // get moved rows
        var movedRows: [(from: RowDescriptor, to: RowDescriptor)] = []
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
            
            // calculate the `from` index path
            let fromRowIdx = move.from.idx - fromSectionOffset
            let fromPath = IndexPath(row: fromRowIdx, section: fromSectionIdx)
            
            // calculate the `to` index path
            let toRowIdx = move.to.idx - toSectionOffset
            let toPath = IndexPath(row: toRowIdx, section: toSectionIdx)
            
            movedRows.append((from: RowDescriptor(indexPath: fromPath, value: move.from.value), to: RowDescriptor(indexPath: toPath, value: move.to.value)))
        }
        self.movedRows = movedRows
        
        
        // get changed rows
        var changedRows: [RowDescriptor] = []
        for changed in changedObjects {
            guard let path = fetchResultBeforeChanges.sections.lookup(snapshot: changed)?.path else {
                continue
            }
            
            changedRows.append(RowDescriptor(indexPath: path, value: changed))
        }
        self.changedRows = changedRows
    }
    
}
