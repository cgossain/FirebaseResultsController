//
//  Section.swift
//  Pods
//
//  Created by Christian Gossain on 2017-02-12.
//
//

import Foundation
import FirebaseDatabase


public class Section {
    
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
    
    /// Initializes a section object with the given section key value and sort descriptors.
    ///
    /// - Parameter sectionKeyValue: The value that represents this section.
    /// - Parameter sortDescriptors: The sort descriptors that describe how items in this sections will be sorted.
    ///
    init(sectionKeyValue: String, sortDescriptors: [NSSortDescriptor]?) {
        self.sectionKeyValue = sectionKeyValue
        self.sortDescriptors = sortDescriptors
    }
    
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
        guard let idx = objects.index(where: { $0.key == snapshot.key }) else {
            return nil
        }
        return idx
    }
    
}

extension Section: CustomStringConvertible {
    
    public var description: String {
        return "<| Section: \(name), Count: \(numberOfObjects) |>"
    }
    
}

extension Section: Hashable {
    
    public static func ==(lhs: Section, rhs: Section) -> Bool {
        if !lhs.sectionKeyValue.isEqual(rhs.sectionKeyValue) {
            return false
        }
        
        // check the objects too??
        
        return true
    }
    
    public var hashValue: Int { return sectionKeyValue.hashValue }
    
}

extension Section: NSCopying {
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let section = Section(sectionKeyValue: sectionKeyValue, sortDescriptors: sortDescriptors)
        section.objects = objects
        return section
    }
    
}
