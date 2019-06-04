//
//  ResultsSection.swift
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

public class ResultsSection {
    /// Name of the section.
    public var name: String { return sectionKeyValue }
    
    /// Number of objects in section.
    public var numberOfObjects: Int { return objects.count }
    
    /// Returns the array of objects in the section.
    public fileprivate(set) var objects: [DataSnapshot] = []
    
    /// The section key value represented by the receiver.
    let sectionKeyValue: String
    
    /// The sort descriptors being used to sorts items in this section.
    let sortDescriptors: [NSSortDescriptor]?
    
    
    // MARK: - Lifecycle
    /// Initializes a section object with the given section key value and sort descriptors.
    ///
    /// - Parameter sectionKeyValue: The value that represents this section.
    /// - Parameter sortDescriptors: The sort descriptors that describe how items in this sections will be sorted.
    ///
    init(sectionKeyValue: String, sortDescriptors: [NSSortDescriptor]?) {
        self.sectionKeyValue = sectionKeyValue
        self.sortDescriptors = sortDescriptors
    }
    
    
    // MARK: - Public
    /// Inserts the given snapshot into the receivers contents and returns the index at which it was inserted.
    @discardableResult
    func insert(snapshot: DataSnapshot) -> Int {
        let idx = objects.insertionIndex(of: snapshot, using: sortDescriptors ?? [])
        objects.insert(snapshot, at: idx)
        return idx
    }
    
    /// Removes the given snapshot from the receivers contents and returns the index from which it was removed.
    @discardableResult
    func remove(snapshot: DataSnapshot) -> Int? {
        guard let idx = index(of: snapshot) else {
            return nil
        }
        
        objects.remove(at: idx)
        return idx
    }
    
    /// Returns the index of the snapshot in the section, or `nil` if it was not found.
    func index(of snapshot: DataSnapshot) -> Int? {
        guard let idx = objects.firstIndex(where: { $0.key == snapshot.key }) else {
            return nil
        }
        return idx
    }
    
}

extension ResultsSection: CustomStringConvertible {
    public var description: String {
        return "<| Section: \(name), Count: \(numberOfObjects) |>"
    }
}

extension ResultsSection: Hashable {
    public static func ==(lhs: ResultsSection, rhs: ResultsSection) -> Bool {
        return lhs.sectionKeyValue == rhs.sectionKeyValue
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(sectionKeyValue)
    }
}

extension ResultsSection: NSCopying {
    public func copy(with zone: NSZone? = nil) -> Any {
        let section = ResultsSection(sectionKeyValue: sectionKeyValue, sortDescriptors: sortDescriptors)
        section.objects = objects
        return section
    }
}
