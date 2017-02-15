//
//  FirebaseResultsController+Additions.swift
//  Pods
//
//  Created by Christian Gossain on 2017-02-12.
//
//

import Foundation
import FirebaseDatabase

extension Array {
    /// From Stack Overflow:
    /// http://stackoverflow.com/questions/26678362/how-do-i-insert-an-element-at-the-correct-position-into-a-sorted-array-in-swift
    ///
    /// Using binary search, finds the index at which a given element should be inserted into an already sorted array (assumes the array is already sorted). This function behaves just like
    /// the NSArray method -indexOfObject:inSortedRange:options:usingComparator:
    func insertionIndex(of element: Element, isOrderedBefore: (Element, Element) -> Bool) -> Int {
        var low = 0
        var high = self.count - 1
        while low <= high {
            let mid = (low + high)/2
            if isOrderedBefore(self[mid], element) {
                low = mid + 1
            } else if isOrderedBefore(element, self[mid]) {
                high = mid - 1
            } else {
                return mid // found at position `mid`
            }
        }
        return low // not found, would be inserted at position `low`
    }
    
}


extension Array where Element: Section {
    
    func contains(snapshot: FIRDataSnapshot) -> Bool {
        if let _ = lookup(snapshot: snapshot) {
            return true
        }
        return false
    }
    
    func lookup(snapshot: FIRDataSnapshot) -> (section: Section, path: IndexPath)? {
        for (sectionIdx, section) in self.enumerated() {
            if let rowIdx = section.indexOf(snapshot: snapshot) {
                return (section: section, path: IndexPath(row: rowIdx, section: sectionIdx))
            }
        }
        return nil
    }
    
    func lookup(sectionKeyValue: String) -> (section: Section, sectionIndex: Int)? {
        for (sectionIdx, section) in self.enumerated() {
            if section.sectionKeyValue == sectionKeyValue {
                return (section: section, sectionIndex: sectionIdx)
            }
        }
        return nil
    }
    
}
