//
//  FirebaseFetchRequest.swift
//
//  Copyright (c) 2017-2018 Christian Gossain
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
        copiedFetchRequest.sortDescriptors = sortDescriptors?.compactMap({ $0.copy() as? NSSortDescriptor })
        
        // return the copied fetch request
        return copiedFetchRequest
    }
}
