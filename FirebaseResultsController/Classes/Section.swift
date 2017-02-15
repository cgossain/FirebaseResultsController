//
//  Section.swift
//  Pods
//
//  Created by Christian Gossain on 2017-02-12.
//
//

import Foundation
import FirebaseDatabase

//struct Row {
//    let object: FIRDataSnapshot
//    let indexPath: IndexPath
//}

public class Section {
    
    struct Row {
        let row: Int
        let object: FIRDataSnapshot
    }
    
    /// Name of the section.
    var name: String { return sectionKeyValue }
    
    /// Number of objects in section.
    var numberOfObjects: Int = 0
    
    /// Returns the array of objects in the section.
    var objects: [FIRDataSnapshot] { return mutableObjects }
    
    /// An index of the objects contained in this section, keyed by the snapshot's key.
    var rowsByKey: [String: Row] {
        if isRowsIndexStale {
            isRowsIndexStale = false
            
            // generate the index
            var rowsByKey = [String: Row]()
            for (idx, snapshot) in objects.enumerated() {
                rowsByKey[snapshot.key] = Row(row: idx, object: snapshot)
            }
            mutableRowsByKey = rowsByKey
        }
        return mutableRowsByKey
    }
    
    /// The section key value represented by the receiver.
    let sectionKeyValue: String
    
    /// The sort descriptors being used to sorts items in this section.
    let sortDescriptors: [NSSortDescriptor]?
    
    /// The internally managed objects.
    fileprivate var mutableObjects = [FIRDataSnapshot]()
    fileprivate var mutableRowsByKey = [String: Row]()
    fileprivate var isRowsIndexStale = true
    
    /// Initializes a section object with the given section key value and sort descriptors.
    ///
    /// - parameters:
    ///     - sectionKeyValue The value that represents this section.
    ///     - sortDescriptors The sort descriptors that describe how items in this sections will be sorted.
    ///
    init(sectionKeyValue: String, sortDescriptors: [NSSortDescriptor]?) {
        self.sectionKeyValue = sectionKeyValue
        self.sortDescriptors = sortDescriptors
    }
    
    /// Inserts the given snapshot into the receivers contents and returns the index at which it was inserted.
    @discardableResult
    func insert(snapshot: FIRDataSnapshot) -> Int {
        isRowsIndexStale = true
        
        let insertionIdx = insertionIndex(for: snapshot)
        mutableObjects.insert(snapshot, at: insertionIdx)
        return insertionIdx
    }
    
    /// Removes the given snapshot from the receivers contents and returns the index from which it was removed.
    @discardableResult
    func remove(snapshot: FIRDataSnapshot) -> Int {
        isRowsIndexStale = true
        
        let removalIndex = indexOf(snapshot: snapshot)!
        _ = mutableObjects.remove(at: removalIndex)
        return removalIndex
    }
    
    /// Returns the index of the given snapshot, or `nil` if the object was not found.
    func indexOf(snapshot: FIRDataSnapshot) -> Int? {
        if isRowsIndexStale {
            // the index is stale, so just seach for the index directly
            return mutableObjects.index { $0.key == snapshot.key }
        }
        else {
            // since we've indexed all rows, we can just quickly get the row from the index
            return rowsByKey[snapshot.key]?.row
        }
    }
    
    /// Returns the index at which the given snapshot should be inserted to maintain the sort order.
    func insertionIndex(for snapshot: FIRDataSnapshot) -> Int {
        return mutableObjects.insertionIndex(of: snapshot, isOrderedBefore: {
            if let descriptors = self.sortDescriptors {
                // determine the effective ordering evaluated against the sortDescriptors
                var result = ComparisonResult.orderedSame
                for descriptor in descriptors {
                    result = descriptor.compare($0.value, to: $1.value)
                    if result != .orderedSame {
                        break
                    }
                }
                
                // if `orderedAscending`, the first element is ordered before the second element
                if result == .orderedAscending {
                    return true
                }
                return false
            }
            else {
                // no sort descriptors, so we'll just sort by the snapshot keys
                return $0.key < $1.key
            }
        })
    }
    
}

extension Section: Hashable {
    
    public static func ==(lhs: Section, rhs: Section) -> Bool {
        return lhs.sectionKeyValue.isEqual(rhs.sectionKeyValue)
    }
    
    public var hashValue: Int { return sectionKeyValue.hashValue }
    
}

extension Section: NSCopying {
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let section = Section(sectionKeyValue: sectionKeyValue, sortDescriptors: sortDescriptors)
        section.mutableObjects = mutableObjects
        return section
    }
    
}
