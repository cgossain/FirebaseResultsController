//
//  FirebaseFetchRequest.swift
//  Pods
//
//  Created by Christian Gossain on 2017-02-12.
//
//

import Foundation
import FirebaseDatabase

public class FirebaseFetchRequest {
    
    /// The database query associated with this fetch request.
    public let query: DatabaseQuery
    
    /// A predicate used by the results controller to filter the query results.
    public var predicate: NSPredicate?
    
    /// An array of sort descriptors used by the results controller to sorts the fetched snapshots in each section.
    public var sortDescriptors: [NSSortDescriptor]?
    
    /// Initializes the fetch request with the given FIRDatabaseQuery.
    public init(query: DatabaseQuery) {
        self.query = query
    }
    
}

extension FirebaseFetchRequest: NSCopying {
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copiedFetchRequest = FirebaseFetchRequest(query: query)
        
        // copy the predicate
        copiedFetchRequest.predicate = predicate?.copy() as? NSPredicate
        
        // copy the sort descriptors
        copiedFetchRequest.sortDescriptors = sortDescriptors?.flatMap({ $0.copy() as? NSSortDescriptor })
        
        // return the copied fetch request
        return copiedFetchRequest
    }
    
}
