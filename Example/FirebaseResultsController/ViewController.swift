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

class ViewController: UITableViewController {
    
    var didFetchInitialData = false
    
    fileprivate let dateCellIdentifier = "dateCellIdentifier"
    
    var willBeginChangingContentTime = Date()
    
    lazy var dates1Ref = Database.database().reference().child("dates1")
    lazy var dates2Ref = Database.database().reference().child("dates2")
    
    lazy var resultsController1: FirebaseResultsController = {
        let query = self.dates1Ref.queryOrderedByKey()
        
        let fetchRequest = FirebaseFetchRequest(query: query)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        let controller = FirebaseResultsController(fetchRequest: fetchRequest, sectionNameKeyPath: "category")
        controller.delegate = self
        controller.changeTracker = self
        return controller
    }()
    
    lazy var resultsController2: FirebaseResultsController = {
        let query = self.dates2Ref.queryOrderedByKey()
        
        let fetchRequest = FirebaseFetchRequest(query: query)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        let controller = FirebaseResultsController(fetchRequest: fetchRequest, sectionNameKeyPath: "category")
        controller.delegate = self
        controller.changeTracker = self
        return controller
    }()
    
    lazy var compoundResultsController: ComposedFirebaseResultsController = {
        let controller = ComposedFirebaseResultsController(controllers: [self.resultsController1,
                                                                         self.resultsController2], composedQuery: nil)
        
        controller.delegate = self
        return controller
    }()
    
    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(ViewController.addButtonTapped(_:)))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: dateCellIdentifier)
        compoundResultsController.performFetch()
    }
    
    @objc func addButtonTapped(_ sender: UIBarButtonItem) {
        let date = randomDate()
        
        if arc4random_uniform(2) == 0 {
            dates1Ref.childByAutoId().setValue(["date": date.timeIntervalSinceReferenceDate,
                                                "category": Int(arc4random_uniform(4))])
        }
        else {
            dates2Ref.childByAutoId().setValue(["date": date.timeIntervalSinceReferenceDate,
                                                "category": 10 + Int(arc4random_uniform(4))])
        }
    }
    
    func randomDate() -> Date {
        let offset = Int(arc4random_uniform(7)) // random day offset from 0 and 6
        let calendar = Calendar.current
        let randomDate = calendar.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return randomDate
    }
    
    func configureCell(_ cell: UITableViewCell, with snapshot: DataSnapshot) {
        if let timeInterval = (snapshot.value as? [String: Any])?["date"] as? Double {
            cell.textLabel?.text = dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: timeInterval))
        }
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return compoundResultsController.sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return compoundResultsController.sections[section].numberOfObjects
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: dateCellIdentifier, for: indexPath)
        let snapshot = try! compoundResultsController.object(at: indexPath)
        configureCell(cell, with: snapshot)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return compoundResultsController.sections[section].name
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let delete = UITableViewRowAction(style: .destructive, title: "Delete") { (action, path) in
            let snapshot = try! self.compoundResultsController.object(at: indexPath)
            snapshot.ref.removeValue()
        }
        return [delete]
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // print the snapshot description
        let snapshot = try! compoundResultsController.object(at: indexPath)
        print("Snapshot: \(snapshot)")
        
        // make sure the controller is spitting back the correct path
        let path = compoundResultsController.indexPath(for: snapshot)
        print("Controller Path: \(String(describing: path))")
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension ViewController: ComposedFirebaseResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: ComposedFirebaseResultsController) {
        willBeginChangingContentTime = Date()
        tableView.beginUpdates()
    }
    
    func controller(_ controller: ComposedFirebaseResultsController, didChange section: ResultsSection, atSectionIndex sectionIndex: Int, for type: ResultsChangeType) {
        switch type {
        case .insert:
            self.tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete:
            self.tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        default:
            return
        }
    }
    
    func controller(_ controller: ComposedFirebaseResultsController, didChange anObject: DataSnapshot, at indexPath: IndexPath?, for type: ResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .fade)
        case .update:
            configureCell(tableView.cellForRow(at: indexPath!)!, with: anObject)
        case .move:
            tableView.deleteRows(at: [indexPath!], with: .fade)
            tableView.insertRows(at: [newIndexPath!], with: .fade)
//            tableView.moveRow(at: indexPath!, to: newIndexPath!)
        }
    }
    
    func controllerDidChangeContent(_ controller: ComposedFirebaseResultsController) {
        let difference = Date().timeIntervalSince(willBeginChangingContentTime)
        print("End: \(difference)")
        
        tableView.endUpdates()
//        tableView.reloadData()
    }
    
}

extension ViewController: FirebaseResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: FirebaseResultsController) {
        willBeginChangingContentTime = Date()
    }
    
    func controllerDidChangeContent(_ controller: FirebaseResultsController) {
        let difference = Date().timeIntervalSince(willBeginChangingContentTime)
        print("End: \(difference)")
    }
    
}

extension ViewController: FirebaseResultsControllerChangeTracking {
    
    func controller(_ controller: FirebaseResultsController, didChangeContentWith changes: FetchResultChanges) {
        tableView.beginUpdates()
        
        // apply section changes
        changes.enumerateSectionChanges { (section, sectionIndex, type) in
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
        changes.enumerateRowChanges { (anObject, indexPath, type, newIndexPath) in
            switch type {
            case .insert:
                tableView.insertRows(at: [newIndexPath!], with: .fade)
            case .delete:
                tableView.deleteRows(at: [indexPath!], with: .fade)
            case .update:
                self.configureCell(tableView.cellForRow(at: indexPath!)!, with: anObject)
            case .move:
                tableView.moveRow(at: indexPath!, to: newIndexPath!)
            }
        }
        
        tableView.endUpdates()
    }
    
}
