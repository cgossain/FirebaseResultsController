//
//  FirebaseResultsController.swift
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
import FetchedResultsController
import FirebaseDatabase

public class FirebaseResultsController: FetchedResultsController<FirebaseRealtimeDatabaseFetchRequest, DataSnapshot> {
    // MARK: - Lifecycle
    /// Initializes the results controller with the given fetch request and an optional sectionNameKeyPath to section fetched data on.
    ///
    /// - parameters:
    ///   - fetchRequest: The fetch request that contains the firebase reference/query to fetch data from.
    ///   - sectionNameKeyPath: A key path on result objects that returns the section name. Pass nil to indicate that the controller should generate a single section.
    ///
    public init(fetchRequest: FirebaseRealtimeDatabaseFetchRequest, sectionNameKeyPath: String?) {
        let dbConnector = FirebaseRealtimeDatabaseStoreConnector()
        super.init(storeConnector: dbConnector, fetchRequest: fetchRequest, sectionNameKeyPath: sectionNameKeyPath)
    }
}
