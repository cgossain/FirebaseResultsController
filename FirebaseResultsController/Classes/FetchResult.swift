//
//  FetchResult.swift
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

private extension FetchResult {
    static let nilSectionName = "" // the name of the `nil` section
}

class FetchResult {
    /// The FirebaseFetchRequest instance used to do the fetching. The sort descriptor used in the request groups objects into sections.
    let fetchRequest: FirebaseFetchRequest
    
    /// The keyPath on the fetched objects used to determine the section they belong to.
    let sectionNameKeyPath: String?
    
    /// The current fetch results ordered by section first (if a `sectionNameKeyPath` was provided), then by the fetch request sort descriptors.
    private(set) var results: [DataSnapshot] = []
    
    /// An array containing the name of each section that exists in the results. The order of the items in this list represent the order that the sections should appear.
    /// - note: If the `sectionNameKeyPath` value is `nil`, a single section will be generated.
    var sectionKeyValues: [String] {
        return Array(sections.map({ $0.sectionKeyValue }))
    }
    
    /// The fetch results as arranged sections.
    var sections: [ResultsSection] {
        if let sections = _sections {
            return sections
        }
        
        // compute the sections array
        let computed = Array(sectionsBySectionKeyValue.values).sorted(by: { $0.sectionKeyValue < $1.sectionKeyValue })
        _sections = computed
        return computed
    }
    private var _sections: [ResultsSection]? // hold the current non-stale sections array
    
    /// A dictionary that maps a section to its `sectionKeyValue`.
    private var sectionsBySectionKeyValue: [String: ResultsSection] = [:]
    
    /// A dictionary that maps a sections' index to its `sectionKeyValue`.
    private var sectionIndicesBySectionKeyValue: [String: Int] = [:]
    
    /// A dictionary that maps the sections' offset (i.e. first index of the section in the overall `results` array) to its `sectionKeyValue`.
    private var sectionOffsetsBySectionKeyValue: [String: Int] = [:]
    
    
    // MARK: - Lifecycle
    /// Initializes a new fetch results objects with the given `fetchRequest` and `sectionNameKeyPath`. These are used to 
    /// filter and order results as snapshots are inserted and removed.
    ///
    /// - parameters:
    ///   - fetchRequest: The fetch request used to retrieve the results.
    ///   - sectionNameKeyPath: The key path on result objects that represents the section name.
    ///   - fetchResult: The fetch result whose contents should be added to the receiver.
    init(fetchRequest: FirebaseFetchRequest, sectionNameKeyPath: String?, fetchResult: FetchResult? = nil) {
        self.fetchRequest = fetchRequest
        self.sectionNameKeyPath = sectionNameKeyPath
        
        // configure initial state with the contents of a previous fetch result
        if let fetchResult = fetchResult {
            results.append(contentsOf: fetchResult.results)
            
            // copy the section objects; we don't want to affect the original fetch results sections when we make changes here
            var copiedSectionsBySectionKeyValue: [String: ResultsSection] = [:]
            for (sectionKeyValue, section) in fetchResult.sectionsBySectionKeyValue {
                copiedSectionsBySectionKeyValue[sectionKeyValue] = section.copy() as? ResultsSection
            }
            sectionsBySectionKeyValue = copiedSectionsBySectionKeyValue
        }
    }
    
    /// Creates a new FetchResult object, initialized with the contents of an existing FetchResult object.
    convenience init(fetchResult: FetchResult) {
        self.init(fetchRequest: fetchResult.fetchRequest, sectionNameKeyPath: fetchResult.sectionNameKeyPath, fetchResult: fetchResult)
    }
    
    
    // MARK: - Internal
    /// Applies the given changes to the current results.
    func apply(inserted: [DataSnapshot], updated: [DataSnapshot], deleted: [DataSnapshot]) {
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
        
        // reset internal state since the contents have changed
        _sections = nil
        sectionIndicesBySectionKeyValue.removeAll()
        sectionOffsetsBySectionKeyValue.removeAll()
    }
    
    /// Returns the section index of the specified snapshot in the receiver's results.
    func sectionIndex(for snapshot: DataSnapshot) -> Int? {
        let sectionKeyValue = snapshot.sectionKeyValue(forSectionNameKeyPath: sectionNameKeyPath)
        
        if let idx = sectionIndicesBySectionKeyValue[sectionKeyValue] {
            return idx
        }
        
        // the index has not yet been computed; lets find it then store it to avoid redundant work the next time this function is called
        guard let idx = sectionKeyValues.firstIndex(where: { $0 == sectionKeyValue }) else {
            return nil
        }
        
        sectionIndicesBySectionKeyValue[sectionKeyValue] = idx
        return idx
    }
    
    /// Returns the index if the first snapshot in the section that the snapshot belongs to.
    func sectionOffset(for snapshot: DataSnapshot) -> Int? {
        let sectionKeyValue = snapshot.sectionKeyValue(forSectionNameKeyPath: sectionNameKeyPath)
        
        if let idx = sectionOffsetsBySectionKeyValue[sectionKeyValue] {
            return idx
        }
        
        // the offset has not yet been computed; lets find it then store it to avoid redundant work the next time this function is called
        guard let idx = results.firstIndex(where: { $0.sectionKeyValue(forSectionNameKeyPath: sectionNameKeyPath) == sectionKeyValue }) else {
            return nil
        }
        
        sectionOffsetsBySectionKeyValue[sectionKeyValue] = idx
        return idx
    }
}

extension DataSnapshot {
    /// Extracts the section key value for the given key path.
    func sectionKeyValue(forSectionNameKeyPath sectionNameKeyPath: String?) -> String {
        if let sectionNameKeyPath = sectionNameKeyPath, let obj = self.value, let value = (obj as AnyObject).value(forKeyPath: sectionNameKeyPath) {
            return String(describing: value)
        }
        return FetchResult.nilSectionName
    }
}

extension FetchResult {
    /// Adds the snapshot to the results at the correct position, and if it evaluates against the fetch request predicate.
    private func insert(snapshot: DataSnapshot) {
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
        let section = sectionsBySectionKeyValue[sectionKeyValue] ?? ResultsSection(sectionKeyValue: sectionKeyValue, sortDescriptors: fetchRequest.sortDescriptors)
        section.insert(snapshot: snapshot)
        sectionsBySectionKeyValue[sectionKeyValue] = section
    }
    
    /// Replaces the existing version of the snapshot with the specified one.
    private func update(snapshot new: DataSnapshot) {
        // since the values will have changed, we cannot remove the "new" version of the snapshot, instead we'll have to locate and remove the "old" version of this snapshot
        // this is important when we are sectionning because the `sectionKeyValue` may have changed
        guard let idx = results.firstIndex(where: { $0.key == new.key }) else {
            return
        }
        
        // remove the old version
        let old = results[idx]
        delete(snapshot: old)
        
        // insert the updated version of the snapshot
        insert(snapshot: new)
    }
    
    /// Removes the snapshot if it exists in the results.
    private func delete(snapshot: DataSnapshot) {
        guard let idx = results.firstIndex(where: { $0.key == snapshot.key }) else {
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
}

extension FetchResult {
    /// Specifies all the sort descriptors that should be used when inserting snapshots (including the `sectionNameKeyPath`).
    private var fetchSortDescriptors: [NSSortDescriptor] {
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
    private func sectionKeyValue(of snapshot: DataSnapshot) -> String {
        return snapshot.sectionKeyValue(forSectionNameKeyPath: self.sectionNameKeyPath)
    }
    
    /// Returns true if the given snapshot should be included in the data set.
    private func canInclude(snapshot: DataSnapshot) -> Bool {
        if let predicate = fetchRequest.predicate {
            return predicate.evaluate(with: snapshot.value)
        }
        return true
    }
}

extension FetchResult: CustomStringConvertible {
    var description: String {
        var components: [String] = []
        let sectionSummaries = sections.map({ return "\($0.sectionKeyValue):\($0.numberOfObjects)" })
        components.append("\(sections.count) sections {Name:Count} \(sectionSummaries.joined(separator: ","))")
        return components.joined(separator: " ")
    }
}
