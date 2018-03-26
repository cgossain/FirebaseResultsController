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
            }
            else if isOrderedBefore(element, self[mid]) {
                high = mid - 1
            }
            else {
                return mid // found at position `mid`
            }
        }
        return low // not found, would be inserted at position `low`
    }
}

extension Array where Element: DataSnapshot {
    /// Returns the index at which you should insert the snapshot in order to maintain a sorted array (according to the given sort descriptors).
    func insertionIndex(of element: Element, using sortDescriptors: [NSSortDescriptor]) -> Int {
        return self.insertionIndex(of: element) {
            var result: ComparisonResult = .orderedSame
            for sortDescriptor in sortDescriptors {
                if let obj1 = $0.value, let obj2 = $1.value {
                    result = sortDescriptor.compare(obj1, to: obj2)
                }
                
                if result != .orderedSame {
                    break
                }
            }
            return (result == .orderedAscending)
        }
    }
}

extension Array where Element: ResultsSection {
    /// Returns the result section and index path of the given snapshot.
    func lookup(snapshot: DataSnapshot) -> (section: ResultsSection, path: IndexPath)? {
        for (sectionIdx, section) in enumerated() {
            if let rowIdx = section.index(of: snapshot) {
                return (section: section, path: IndexPath(row: rowIdx, section: sectionIdx))
            }
        }
        return nil
    }
}
