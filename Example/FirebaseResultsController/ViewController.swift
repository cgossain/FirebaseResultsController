//
//  ViewController.swift
//  FirebaseResultsController
//
//  Created by cgossain@gmail.com on 02/12/2017.
//  Copyright (c) 2017 cgossain@gmail.com. All rights reserved.
//

import UIKit
import FirebaseResultsController
import Firebase

extension Date {
    static func makeRandomDate() -> Date {
        let offset = Int(arc4random_uniform(7)) // random day offset from 0 and 6
        let calendar = Calendar.current
        let randomDate = calendar.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return randomDate
    }
}

class ViewController: UITableViewController {
    lazy var dates1Ref = Database.database().reference().child("dates1")
    lazy var dates2Ref = Database.database().reference().child("dates2")
    
    lazy var resultsController1: FirebaseResultsController = {
        let query = self.dates1Ref.queryOrderedByKey()
        
        let fetchRequest = FirebaseRealtimeDatabaseFetchRequest(query: query)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "value.date", ascending: true)]
        
        let controller = FirebaseResultsController(fetchRequest: fetchRequest, sectionNameKeyPath: "value.category")
        return controller
    }()
    
    lazy var resultsController2: FirebaseResultsController = {
        let query = self.dates2Ref.queryOrderedByKey()
        
        let fetchRequest = FirebaseRealtimeDatabaseFetchRequest(query: query)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "value.date", ascending: true)]
        
        let controller = FirebaseResultsController(fetchRequest: fetchRequest, sectionNameKeyPath: "value.category")
        return controller
    }()
    
    
    // MARK: - Private Properties
    private let cellIdentifier = "cellIdentifier"
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
    
//    var didFetchInitialData = false
//    var willBeginChangingContentTime = Date()
    
//    lazy var compoundResultsController: ComposedFirebaseResultsController = {
//        let controller = ComposedFirebaseResultsController(controllers: [self.resultsController1, self.resultsController2], composedQuery: nil)
//        controller.delegate = self
//        return controller
//    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(ViewController.addButtonTapped(_:)))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        
        // configure the results controller
        resultsController1.changeTracker.controllerDidChangeResults = { [unowned self] (controller, difference) in
            self.tableView.performBatchUpdates({
                // apply section changes
                difference.enumerateSectionChanges { (section, sectionIndex, type) in
                    switch type {
                    case .insert:
                        self.tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
                    case .delete:
                        self.tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
                    default:
                        break
                    }
                }

                // apply row changes
                difference.enumerateRowChanges { (anObject, indexPath, type, newIndexPath) in
                    switch type {
                    case .insert:
                        self.tableView.insertRows(at: [newIndexPath!], with: .fade)
                    case .delete:
                        self.tableView.deleteRows(at: [indexPath!], with: .fade)
                    case .update:
                        let cell = self.tableView.cellForRow(at: indexPath!)!
                        self.configureCell(cell, with: anObject)
                    case .move:
                        self.tableView.moveRow(at: indexPath!, to: newIndexPath!)
                    }
                }
            })
        }
        resultsController1.performFetch()
    }
    
    @objc func addButtonTapped(_ sender: UIBarButtonItem) {
        let date = Date.makeRandomDate()
        dates1Ref.childByAutoId().setValue(["date": date.timeIntervalSinceReferenceDate, "category": Int(arc4random_uniform(4))])
        
//        if arc4random_uniform(2) == 0 {
//            dates1Ref.childByAutoId().setValue(["date": date.timeIntervalSinceReferenceDate, "category": Int(arc4random_uniform(4))])
//        }
//        else {
//            dates2Ref.childByAutoId().setValue(["date": date.timeIntervalSinceReferenceDate, "category": 10 + Int(arc4random_uniform(4))])
//        }
    }
        
    func configureCell(_ cell: UITableViewCell, with snapshot: DataSnapshot) {
        if let timeInterval = (snapshot.value as? [String: Any])?["date"] as? Double {
            cell.textLabel?.text = dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: timeInterval))
        }
    }
    
    
    // MARK: - UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return resultsController1.sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return resultsController1.sections[section].numberOfObjects
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        let snapshot = try! resultsController1.object(at: indexPath)
        configureCell(cell, with: snapshot)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return resultsController1.sections[section].name
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [unowned self] (action, view, completionHandler) in
            let snapshot = try! self.resultsController1.object(at: indexPath)
            snapshot.ref.removeValue()
            self.resultsController1.storeConnector.processPendingChanges()
            completionHandler(true)
        }
        
        let config = UISwipeActionsConfiguration(actions: [delete])
        config.performsFirstActionWithFullSwipe = true
        
        return config
    }
    
//    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        // print the snapshot description
//        let snapshot = try! compoundResultsController.object(at: indexPath)
//        print("Snapshot: \(snapshot)")
//
//        // make sure the controller is spitting back the correct path
//        let path = compoundResultsController.indexPath(for: snapshot)
//        print("Controller Path: \(String(describing: path))")
//
//        tableView.deselectRow(at: indexPath, animated: true)
//    }
}

//extension ViewController: ComposedFirebaseResultsControllerDelegate {
//    func controllerWillChangeContent(_ controller: ComposedFirebaseResultsController) {
////        willBeginChangingContentTime = Date()
//        tableView.beginUpdates()
//    }
//
//    func controller(_ controller: ComposedFirebaseResultsController, didChange section: ResultsSection, atSectionIndex sectionIndex: Int, for type: ResultsChangeType) {
//        switch type {
//        case .insert:
//            self.tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
//        case .delete:
//            self.tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
//        default:
//            return
//        }
//    }
//
//    func controller(_ controller: ComposedFirebaseResultsController, didChange anObject: DataSnapshot, at indexPath: IndexPath?, for type: ResultsChangeType, newIndexPath: IndexPath?) {
//        switch type {
//        case .insert:
//            tableView.insertRows(at: [newIndexPath!], with: .fade)
//        case .delete:
//            tableView.deleteRows(at: [indexPath!], with: .fade)
//        case .update:
//            configureCell(tableView.cellForRow(at: indexPath!)!, with: anObject)
//        case .move:
//            tableView.deleteRows(at: [indexPath!], with: .fade)
//            tableView.insertRows(at: [newIndexPath!], with: .fade)
////            tableView.moveRow(at: indexPath!, to: newIndexPath!)
//        }
//    }
//
//    func controllerDidChangeContent(_ controller: ComposedFirebaseResultsController) {
////        let difference = Date().timeIntervalSince(willBeginChangingContentTime)
////        print("End: \(difference)")
//
//        tableView.endUpdates()
////        tableView.reloadData()
//    }
//}

//extension ViewController: FirebaseResultsControllerDelegate {
//    func controllerWillChangeContent(_ controller: FirebaseResultsController) {
////        willBeginChangingContentTime = Date()
//        print("CURR|\(controller.description)")
//    }
//
//    func controllerDidChangeContent(_ controller: FirebaseResultsController) {
////        let difference = Date().timeIntervalSince(willBeginChangingContentTime)
////        print("End: \(difference)")
////        print(controller.description)
//    }
//}

//extension ViewController: FirebaseResultsControllerChangeTracking {
//    func controller(_ controller: FirebaseResultsController, didChangeContentWith changes: FetchResultChanges) {
//        print("DIFF|\(changes.description)")
//
//        tableView.beginUpdates()
//
//        // apply section changes
//        changes.enumerateSectionChanges { (section, sectionIndex, type) in
//            switch type {
//            case .insert:
//                self.tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
//            case .delete:
//                self.tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
//            default:
//                break
//            }
//        }
//
//        // apply row changes
//        changes.enumerateRowChanges { (anObject, indexPath, type, newIndexPath) in
//            switch type {
//            case .insert:
//                tableView.insertRows(at: [newIndexPath!], with: .fade)
//            case .delete:
//                tableView.deleteRows(at: [indexPath!], with: .fade)
//            case .update:
//                self.configureCell(tableView.cellForRow(at: indexPath!)!, with: anObject)
//            case .move:
//                tableView.moveRow(at: indexPath!, to: newIndexPath!)
//            }
//        }
//
//        tableView.endUpdates()
//    }
//}
