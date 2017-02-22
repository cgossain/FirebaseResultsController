//
//  CompoundFirebaseResultsController.swift
//  Pods
//
//  Created by Christian Gossain on 2017-02-20.
//
//

import Foundation
import FirebaseDatabase

public enum CompoundFirebaseResultsControllerError: Error {
    case invalidSectionIndex(idx: Int)
}


public protocol CompoundFirebaseResultsControllerDelegate: class {
    
    /// Notifies the delegate that a fetched object has been changed due to an add, remove, move, or update.
    func controller(_ controller: CompoundFirebaseResultsController, didChange anObject: FIRDataSnapshot, at indexPath: IndexPath?, for type: ResultsChangeType, newIndexPath: IndexPath?)
    
    /// Notifies the delegate of added or removed sections.
    func controller(_ controller: CompoundFirebaseResultsController, didChange section: Section, atSectionIndex sectionIndex: Int, for type: ResultsChangeType)
    
    /// Called when the results controller begins receiving changes.
    func controllerWillChangeContent(_ controller: CompoundFirebaseResultsController)
    
    /// Called when the controller has completed processing the all changes.
    func controllerDidChangeContent(_ controller: CompoundFirebaseResultsController)
    
}

/**
 Combines the results from individual results controllers into a single controller.
 */
public class CompoundFirebaseResultsController {
    
    public let controllers: [FirebaseResultsController]
    
    /// The object that is notified when the fetched results changed.
    public weak var delegate: CompoundFirebaseResultsControllerDelegate?
    
    /// The combined sections of the individual controller fetch results.
    public var sections: [Section] { return controllers.flatMap({ $0.sections }) }
    
    /// The current number of controllers currently changing their results.
    fileprivate var changing = 0
    
    // MARK: - Lifecycle
    
    /// Initializes the controller with the specified results controllers.
    public init(controllers: [FirebaseResultsController]) {
        self.controllers = controllers
    }
    
    /**
     Executes the fetch described by the fetch request. You must call this method to start fetching the initial data and to setup the query observers.
     If you change the sort decriptors or predicate on the fetch request, you must call this method to reconfigure the receiver for the updated fetch request.
     */
    public func performFetch() {
        // make sure the delegate if first set on all the controllers
        // this is important becuase we need to have balanced calls to `controllerWillChangeContent`, and `controllerDidChangeContent`
        controllers.forEach {
            $0.delegate = self
        }
        
        // start the fetch on each controller
        controllers.forEach {
            $0.performFetch()
        }
    }
    
    /// Returns the snapshot at a given indexPath.
    ///
    /// - parameters:
    ///     - at: An index path in the fetch results. If indexPath does not describe a valid index path in the fetch results, an error is thrown.
    ///
    /// - returns: The object at a given index path in the fetch results.
    public func object(at: IndexPath) throws -> FIRDataSnapshot {
        let controller = try resultsController(forSectionIndex: at.section)
        let path = indexPath(in: controller, fromCompoundIndexPath: at)
        return try controller.object(at: path)
    }
    
    /// Returns the indexPath of a given snapshot.
    ///
    /// - parameters:
    ///     - for: An object in the receiver’s fetch results.
    ///
    /// - returns: The index path of object in the receiver’s fetch results, or nil if object could not be found.
    public func indexPath(for snapshot: FIRDataSnapshot) -> IndexPath? {
        return sections.lookup(snapshot: snapshot)?.path
    }
    
    /// Returns the controller that manages the data at the given section index.
    public func resultsController(forSectionIndex sectionIndex: Int) throws -> FirebaseResultsController {
        var sectionOffset = 0
        
        for controller in controllers {
            sectionOffset += controller.sections.count
            
            if sectionIndex < sectionOffset {
                return controller
            }
        }
        
        throw CompoundFirebaseResultsControllerError.invalidSectionIndex(idx: sectionIndex)
    }
    
}

extension CompoundFirebaseResultsController {
    
    /// Returns the index path in the overall results, from an index path within a given results controller.
    fileprivate func compoundIndexPath(for path: IndexPath, in controller: FirebaseResultsController) -> IndexPath {
        let sectionOffset = self.sectionOffset(for: controller)
        return IndexPath(row: path.row, section: sectionOffset + path.section)
    }
    
    /// Returns the index path within a given controller, from an index path specified in the overall results.
    fileprivate func indexPath(in controller: FirebaseResultsController, fromCompoundIndexPath path: IndexPath) -> IndexPath {
        let sectionOffset = self.sectionOffset(for: controller)
        return IndexPath(row: path.row, section: path.section - sectionOffset)
    }
    
    /// Returns the index of the first section of the given controller in the overall sections.
    fileprivate func sectionOffset(for resultsController: FirebaseResultsController) -> Int {
        var offset = 0
        for controller in controllers {
            if resultsController === controller {
                break
            }
            
            offset += controller.sections.count
        }
        return offset
    }
    
}

extension CompoundFirebaseResultsController: FirebaseResultsControllerDelegate {
    
    public func controllerWillChangeContent(_ controller: FirebaseResultsController) {
        if changing == 0 {
            delegate?.controllerWillChangeContent(self)
        }
        
        // keep track of the number of controllers that are changing
        changing += 1
    }
    
    public func controller(_ controller: FirebaseResultsController, didChange section: Section, atSectionIndex sectionIndex: Int, for type: ResultsChangeType) {
        let sectionOffset = self.sectionOffset(for: controller)
        delegate?.controller(self, didChange: section, atSectionIndex: (sectionOffset + sectionIndex), for: type)
    }
    
    public func controller(_ controller: FirebaseResultsController, didChange anObject: FIRDataSnapshot, at indexPath: IndexPath?, for type: ResultsChangeType, newIndexPath: IndexPath?) {
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
    
    public func controllerDidChangeContent(_ controller: FirebaseResultsController) {
        if changing > 0 {
            changing -= 1
        }
        
        // the compound controller can notify that it has changed its content, if all the controllers have finished changing
        if changing == 0 {
            delegate?.controllerDidChangeContent(self)
        }
    }
    
}