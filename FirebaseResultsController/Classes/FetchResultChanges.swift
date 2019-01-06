//
//  FetchResultChanges.swift
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
import FirebaseDatabase
import Dwifft

/// Simplifies filtering.
fileprivate extension DiffStep {
    var isInserted: Bool {
        switch self {
        case .insert(_, _):
            return true
        case .delete(_, _):
            return false
        }
    }
}

/// A FetchResultChanges object provides detailed information about the differences between two fetch
/// results. The changes object provides information useful for updating a UI that lists the contents
/// of a fetch result, such as the indexes of added, removed, and rearranged objects.
public struct FetchResultChanges {
    public struct Section {
        let idx: Int
        let section: ResultsSection
    }
    
    public struct Row {
        let indexPath: IndexPath
        let value: DataSnapshot
    }
    
    /// The fetch result before applying the changes.
    let fetchResultBeforeChanges: FetchResult
    
    /// The fetch result after applying the changes.
    let fetchResultAfterChanges: FetchResult
    
    /// The indexes of the removed sections, relative to the 'before' state.
    public fileprivate(set) var removedSections: [Section]?
    
    /// The index paths of the removed rows, relative to the 'before' state.
    public fileprivate(set) var removedRows: [Row]?

    /// The indexes of the inserted sections, relative to the 'before' state, after deletions have been applied.
    public fileprivate(set) var insertedSections: [Section]?
    
    /// The index paths of the inserted rows, relative to the 'before' state, after deletions have been applied.
    public fileprivate(set) var insertedRows: [Row]?
    
    /// The index paths of the moved rows.
    public fileprivate(set) var movedRows: [(from: Row, to: Row)]?
    
    /// The index paths of the changed rows, relative to the 'before' state.
    public fileprivate(set) var changedRows: [Row]?
    
    
    // MARK: - Lifecycle
    /// Creates a diff between two fetch result objects.
    ///
    /// - parameters:
    ///     - fromResult: The fetch result object with the state of objects before the change.
    ///     - toResult: The fetch result object with the state of objects after the change.
    ///     - changedObjects: The objects in the fetch result whose content been updated.
    init(fromResult: FetchResult, toResult: FetchResult, changedObjects: [DataSnapshot]) {
        fetchResultBeforeChanges = fromResult
        fetchResultAfterChanges = toResult
        
        var mutableChangedObjects = changedObjects
        
        // compute the sections diff
        let sectionsDiff = Dwifft.diff(fetchResultBeforeChanges.sectionKeyValues, fetchResultAfterChanges.sectionKeyValues)
        
        // compute the rows diff
        let rowsDiff = Dwifft.diff(fetchResultBeforeChanges.results, fetchResultAfterChanges.results)
        
        // compute deleted sections
        self.removedSections = sectionsDiff.filter({ !$0.isInserted }).map({ Section(idx: $0.idx, section: fetchResultBeforeChanges.sections[$0.idx]) })
        
        // compute inserted sections
        self.insertedSections = sectionsDiff.filter({ $0.isInserted }).map({ Section(idx: $0.idx, section: fetchResultAfterChanges.sections[$0.idx]) })
        
        // prep to compute moved rows
        var deletions = rowsDiff.filter({ !$0.isInserted })
        var insertions = rowsDiff.filter({ $0.isInserted })
        var moves: [(from: DiffStep<DataSnapshot>, to: DiffStep<DataSnapshot>)] = []
        
        // A "move" is a special type of change. Specifically, it involves a row being removed from one location, and then being
        // inserted at a new location. The following 2 steps will extract moved row from the inserted and deleted lists.
        
        // 1. We first need to identify the moved rows by simply checking that a deleted row also shows up as an inserted row.
        for deletion in deletions {
            if let insertion = insertions.filter({ $0.value.key == deletion.value.key }).first {                
                moves.append((from: deletion, to: insertion))
            }
        }
        
        // 2. Once we've identified our moved rows, we need to remove those rows from both the deletions and insertions lists so as not
        // to "double dip". In otherwords we are saying that we will interpret those specific insertions and deletions as moves.
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
        
        // compute inserted rows
        var insertedRows: [Row] = []
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
            insertedRows.append(Row(indexPath: indexPath, value: inserted.value))
        }
        self.insertedRows = insertedRows
        
        // compute deleted rows
        var removedRows: [Row] = []
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
            removedRows.append(Row(indexPath: indexPath, value: removed.value))
        }
        self.removedRows = removedRows
        
        // compute moved rows
        var movedRows: [(from: Row, to: Row)] = []
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
            
            // track the moved row
            movedRows.append((from: Row(indexPath: fromPath, value: move.from.value), to: Row(indexPath: toPath, value: move.to.value)))
            
            // remove moved objects from the changed objects list, this ensures it does not get tracked as a change as well
            if let idx = mutableChangedObjects.index(of: move.to.value) {
                mutableChangedObjects.remove(at: idx)
            }
        }
        self.movedRows = movedRows
        
        // compute changed/updated rows
        var changedRows: [Row] = []
        for changed in mutableChangedObjects {
            guard let path = fetchResultBeforeChanges.sections.lookup(snapshot: changed)?.path else {
                continue
            }
            
            changedRows.append(Row(indexPath: path, value: changed))
        }
        self.changedRows = changedRows
    }
    
    
    // MARK: - Public
    /// Convenience method that enumerates all the section changes described by the receiver.
    public func enumerateSectionChanges(_ body: ((_ section: ResultsSection, _ sectionIndex: Int, _ type: ResultsChangeType) -> Void)) {
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
    public func enumerateRowChanges(_ body: ((_ anObject: DataSnapshot, _ indexPath: IndexPath?, _ type: ResultsChangeType, _ newIndexPath: IndexPath?) -> Void)) {
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
