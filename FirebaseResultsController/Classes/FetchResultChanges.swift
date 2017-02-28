//
//  FetchResultChanges.swift
//  Pods
//
//  Created by Christian Gossain on 2017-02-17.
//
//

import Foundation
import FirebaseDatabase
import Dwifft

public struct SectionDescriptor {
    let idx: Int
    let section: Section
}

public struct RowDescriptor {
    let indexPath: IndexPath
    let value: FIRDataSnapshot
}

public struct FetchResultChanges {
    
    /// The fetch result before applying the changes.
    let fetchResultBeforeChanges: FetchResult
    
    /// The fetch result after applying the changes.
    let fetchResultAfterChanges: FetchResult
    
    /// The indexes of the removed sections, relative to the 'before' state.
    public fileprivate(set) var removedSections: [SectionDescriptor]?
    
    /// The index paths of the removed rows, relative to the 'before' state.
    public fileprivate(set) var removedRows: [RowDescriptor]?

    /// The indexes of the inserted sections, relative to the 'before' state, after deletions have been applied.
    public fileprivate(set) var insertedSections: [SectionDescriptor]?
    
    /// The index paths of the inserted rows, relative to the 'before' state, after deletions have been applied.
    public fileprivate(set) var insertedRows: [RowDescriptor]?
    
    /// The index paths of the moved rows.
    public fileprivate(set) var movedRows: [(from: RowDescriptor, to: RowDescriptor)]?
    
    /// The index paths of the changed rows, relative to the 'before' state.
    public fileprivate(set) var changedRows: [RowDescriptor]?
    
    
    // MARK: - Initilization
    
    /// Creates a diff between two fetch result objects.
    init(from fromResult: FetchResult, to toResult: FetchResult, changedObjects: [FIRDataSnapshot]) {
        fetchResultBeforeChanges = fromResult
        fetchResultAfterChanges = toResult
        
        var mutableChangedObjects = changedObjects
        
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
            
            // if the index paths have actually changed track this as a move
            if fromPath != toPath {
                movedRows.append((from: RowDescriptor(indexPath: fromPath, value: move.from.value), to: RowDescriptor(indexPath: toPath, value: move.to.value)))
                
                // remove moved objects from the changed objects list
                if let idx = mutableChangedObjects.index(of: move.to.value) {
                    mutableChangedObjects.remove(at: idx)
                }
            }
        }
        self.movedRows = movedRows
        
        
        // get changed rows
        var changedRows: [RowDescriptor] = []
        for changed in mutableChangedObjects {
            guard let path = fetchResultBeforeChanges.sections.lookup(snapshot: changed)?.path else {
                continue
            }
            
            changedRows.append(RowDescriptor(indexPath: path, value: changed))
        }
        self.changedRows = changedRows
    }
    
    // MARK: - Public
    
    /// Convenience method that enumerates all the section changes described by the receiver.
    public func enumerateSectionChanges(_ body: ((_ section: Section, _ sectionIndex: Int, _ type: ResultsChangeType) -> Void)) {
        
        // removed sections
        if let removedSections = removedSections {
            for section in removedSections {
                body(section.section, section.idx, .delete)
            }
        }
        
        // inserted sections
        if let insertedSections = insertedSections {
            for section in insertedSections {
                body(section.section, section.idx, .insert)
            }
        }
        
    }
    
    /// Convenience method that enumerates all the row changes described by the receiver.
    public func enumerateRowChanges(_ body: ((_ anObject: FIRDataSnapshot, _ indexPath: IndexPath?, _ type: ResultsChangeType, _ newIndexPath: IndexPath?) -> Void)) {
        
        // changed rows
        if let changedRows = changedRows {
            for row in changedRows {
                body(row.value, row.indexPath, .update, nil)
            }
        }
        
        // removed rows
        if let removedRows = removedRows {
            for row in removedRows {
                body(row.value, row.indexPath, .delete, nil)
            }
        }
        
        // inserted rows
        if let insertedRows = insertedRows {
            for row in insertedRows {
                body(row.value, nil, .insert, row.indexPath)
            }
        }
        
        // moved rows
        if let movedRows = movedRows {
            for move in movedRows {
                body(move.to.value, move.from.indexPath, .move, move.to.indexPath)
            }
        }
        
    }
    
}
