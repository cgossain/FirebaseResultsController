//
//  ComposedFirebaseResultsController.swift
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

public enum ComposedFirebaseResultsControllerError: Error {
    case invalidSectionIndex(idx: Int)
}

public protocol ComposedFirebaseResultsControllerDelegate: class {
    /// Notifies the delegate that a fetched object has been changed due to an add, remove, move, or update.
    func controller(_ controller: ComposedFirebaseResultsController, didChange anObject: DataSnapshot, at indexPath: IndexPath?, for type: ResultsChangeType, newIndexPath: IndexPath?)
    
    /// Notifies the delegate of added or removed sections.
    func controller(_ controller: ComposedFirebaseResultsController, didChange section: ResultsSection, atSectionIndex sectionIndex: Int, for type: ResultsChangeType)
    
    /// Called when the results controller begins receiving changes.
    func controllerWillChangeContent(_ controller: ComposedFirebaseResultsController)
    
    /// Called when the controller has completed processing the all changes.
    func controllerDidChangeContent(_ controller: ComposedFirebaseResultsController)
}

/// Combines the results from individual results controllers into a single controller.
public class ComposedFirebaseResultsController {
    /// The individual result controllers managed by the receiver.
    public let controllers: [FirebaseResultsController]
    
    /// The composed query passed on initialization.
    public let composedQuery: ComposedFirebaseQuery?
    
    /// The object that is notified when the fetched results change.
    public weak var delegate: ComposedFirebaseResultsControllerDelegate?
    
    /// The combined sections of the individual controller fetch results.
    public var sections: [ResultsSection] { return controllers.flatMap({ $0.sections }) }
    
    /// Inidicates if the controller is currently loading content.
    public var isLoading: Bool {
        var changing = 0
        
        // check the individual controllers
        for controller in controllers {
            if controller.state == .loading {
                changing += 1
            }
        }
        
        // check the composed query
        if let composedQuery = composedQuery, composedQuery.state == .loading {
            changing += 1
        }
        
        return (changing > 0)
    }
    
    /// Tracks whether the current update pass is fully, or partially due to the composed query updating. This value is only useful
    /// between calls to controllerWillChangeContent and controllerDidChangeContent. It is immediately reset to false after controllerDidChangeContent returns.
    public fileprivate(set) var composedQueryUpdated = false
    
    /// Internally used to track diffs by results controller. It's important to only process the diff when all controllers have finished changing.
    fileprivate var pendingChangesByController: [FirebaseResultsController: FetchResultChanges] = [:]
    
    
    // MARK: - Lifecycle
    /// Initializes the controller with the specified results controllers.
    ///
    /// - parameters:
    ///     - controllers: An array of result controllers whose data should be aggregated in the same order provided.
    ///     - composedQuery: An optional composed query that should be fetched alongside the provided result controllers.
    public init(controllers: [FirebaseResultsController], composedQuery: ComposedFirebaseQuery?) {
        self.controllers = controllers
        self.composedQuery = composedQuery
    }
    
    
    /// Executes the fetch described by the fetch request. You must call this method to start fetching the initial data and to setup the query observers.
    /// If you change the sort decriptors or predicate on the fetch request, you must call this method to reconfigure the receiver for the updated fetch request.
    public func performFetch() {
        // start the fetch on each controller
        for controller in controllers {
            controller.delegate = self
            controller.changeTracker = self
            controller.performFetch()
        }
        
        // start the fetch on the composed query
        composedQuery?.delegate = self
        composedQuery?.performFetch()
    }
    
    /// Returns the snapshot at a given indexPath.
    ///
    /// - parameters:
    ///     - indexPath: An index path in the fetch results. If indexPath does not describe a valid index path in the fetch results, an error is thrown.
    ///
    /// - returns: The object at a given index path in the fetch results.
    public func object(at indexPath: IndexPath) throws -> DataSnapshot {
        let controller = try resultsController(forSectionIndex: indexPath.section)
        let path = self.indexPath(in: controller, fromCompoundIndexPath: indexPath)
        return try controller.object(at: path)
    }
    
    /// Returns the indexPath of a given snapshot.
    ///
    /// - parameters:
    ///     - snapshot: An object in the receiver’s fetch results.
    ///
    /// - returns: The index path of object in the receiver’s fetch results, or nil if object could not be found.
    public func indexPath(for snapshot: DataSnapshot) -> IndexPath? {
        return sections.lookup(snapshot: snapshot)?.path
    }
    
    /// Returns the result controller that manages the data at the given section index.
    ///
    /// - parameters:
    ///     - sectionIndex: A section index in the composed controller.
    public func resultsController(forSectionIndex sectionIndex: Int) throws -> FirebaseResultsController {
        var sectionOffset = 0
        
        for controller in controllers {
            sectionOffset += controller.sections.count
            
            if sectionIndex < sectionOffset {
                return controller
            }
        }
        
        throw ComposedFirebaseResultsControllerError.invalidSectionIndex(idx: sectionIndex)
    }
    
}

fileprivate extension ComposedFirebaseResultsController {
    /// Returns the index path in the overall results, from an index path within a given results controller.
    func compoundIndexPath(for path: IndexPath, in controller: FirebaseResultsController) -> IndexPath {
        let sectionOffset = self.sectionOffset(for: controller)
        return IndexPath(row: path.row, section: sectionOffset + path.section)
    }
    
    /// Returns the index path within a given controller, from an index path specified in the overall results.
    func indexPath(in controller: FirebaseResultsController, fromCompoundIndexPath path: IndexPath) -> IndexPath {
        let sectionOffset = self.sectionOffset(for: controller)
        return IndexPath(row: path.row, section: path.section - sectionOffset)
    }
    
    /// Returns the index of the first section of the given controller in the overall sections.
    func sectionOffset(for resultsController: FirebaseResultsController) -> Int {
        var offset = 0
        for controller in controllers {
            if resultsController == controller {
                break
            }
            
            offset += controller.sections.count
        }
        return offset
    }
    
    func notifyWillChangeContent() {
    }
    
    func notifyDidChangeContent() {
        if !isLoading {
            // notify the delegate
            delegate?.controllerWillChangeContent(self)
            
            // process diffs
            processPendingChanges()
            
            // notify the delegate
            delegate?.controllerDidChangeContent(self)
            
            // reset
            composedQueryUpdated = false
        }
    }
}

extension ComposedFirebaseResultsController: FirebaseResultsControllerDelegate {
    public func controllerWillChangeContent(_ controller: FirebaseResultsController) {
        notifyWillChangeContent()
    }
    
    public func controllerDidChangeContent(_ controller: FirebaseResultsController) {
        notifyDidChangeContent()
    }
}

extension ComposedFirebaseResultsController: FirebaseResultsControllerChangeTracking {
    public func controller(_ controller: FirebaseResultsController, didChangeContentWith changes: FetchResultChanges) {
        pendingChangesByController[controller] = changes
    }
}

extension ComposedFirebaseResultsController: ComposedFirebaseQueryDelegate {
    public func queryWillChangeContent(_ query: ComposedFirebaseQuery) {
        notifyWillChangeContent()
    }
    
    public func queryDidChangeContent(_ query: ComposedFirebaseQuery) {
        composedQueryUpdated = true
        
        // complete the update if needed
        notifyDidChangeContent()
    }
}

fileprivate extension ComposedFirebaseResultsController {
     func processPendingChanges() {
        for (controller, changes) in pendingChangesByController {
            // apply section changes
            changes.enumerateSectionChanges { (section, sectionIndex, type) in
                let sectionOffset = self.sectionOffset(for: controller)
                delegate?.controller(self, didChange: section, atSectionIndex: (sectionOffset + sectionIndex), for: type)
            }
            
            // apply row changes
            changes.enumerateRowChanges { (anObject, indexPath, type, newIndexPath) in
                
                // translate the `indexPath` if specified
                var compoundIndexPath: IndexPath?
                if let path = indexPath {
                    compoundIndexPath = self.compoundIndexPath(for: path, in: controller)
                }
                
                // translate the `newIndexPath` if specified
                var compoundNewIndexPath: IndexPath?
                if let path = newIndexPath {
                    compoundNewIndexPath = self.compoundIndexPath(for: path, in: controller)
                }
                
                delegate?.controller(self, didChange: anObject, at: compoundIndexPath, for: type, newIndexPath: compoundNewIndexPath)
            }
            
        }
        
        pendingChangesByController.removeAll()
    }
}
