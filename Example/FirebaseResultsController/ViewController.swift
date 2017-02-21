//
//  ViewController.swift
//  FirebaseResultsController
//
//  Created by cgossain@gmail.com on 02/12/2017.
//  Copyright (c) 2017 cgossain@gmail.com. All rights reserved.
//

import UIKit
import FirebaseResultsController
import FirebaseDatabase

class ViewController: UITableViewController {
    
    var didFetchInitialData = false
    
    fileprivate let dateCellIdentifier = "dateCellIdentifier"
    
    var willBeginChangingContentTime = Date()
    
    lazy var dates1Ref = FIRDatabase.database().reference().child("dates1")
    lazy var dates2Ref = FIRDatabase.database().reference().child("dates2")
    
    lazy var resultsController1: FirebaseResultsController = {
        let query = self.dates1Ref.queryOrderedByKey()
        
        let fetchRequest = FirebaseFetchRequest(query: query)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        let controller = FirebaseResultsController(fetchRequest: fetchRequest, sectionNameKeyPath: "category")
//        controller.delegate = self
        return controller
    }()
    
    lazy var resultsController2: FirebaseResultsController = {
        let query = self.dates2Ref.queryOrderedByKey()
        
        let fetchRequest = FirebaseFetchRequest(query: query)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        let controller = FirebaseResultsController(fetchRequest: fetchRequest, sectionNameKeyPath: "category")
//        controller.delegate = self
        return controller
    }()
    
    lazy var compoundResultsController: CompoundFirebaseResultsController = {
        let controller = CompoundFirebaseResultsController(controllers: [self.resultsController1,
                                                                         self.resultsController2])
        
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
        if let timeInterval = (snapshot.value as? [String: Any])?["date"] as? Double {
            cell.textLabel?.text = dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: timeInterval))
        }
        
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
        print("Controller Path: \(path)")
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension ViewController: CompoundFirebaseResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: CompoundFirebaseResultsController) {
        
    }
    
    func controllerDidChangeContent(_ controller: CompoundFirebaseResultsController) {
        self.tableView.reloadData()
    }
    
}

//extension ViewController: FirebaseResultsControllerDelegate {
//    
//    func controllerWillChangeContent(_ controller: FirebaseResultsController) {
//        willBeginChangingContentTime = Date()
//    }
//    
//    func controllerDidChangeContent(_ controller: FirebaseResultsController, changes: FetchResultDiff) {
//        
//        
//        
//        
//        if !didFetchInitialData {
//            didFetchInitialData = true
//            
//            tableView.reloadData()
//            
//            return
//        }
//        
//        
//        tableView.beginUpdates()
//        
//        // inserted sections
//        if let inserted = changes.insertedSections {
//            tableView.insertSections(inserted, with: .fade)
//        }
//        
//        // removed sections
//        if let removed = changes.removedSections {
//            tableView.deleteSections(removed, with: .fade)
//        }
//        
//        // inserted rows
//        if let inserted = changes.insertedRows {
//            tableView.insertRows(at: inserted, with: .fade)
//        }
//        
//        // removed rows
//        if let removed = changes.removedRows {
//            tableView.deleteRows(at: removed, with: .fade)
//        }
//        
//        // moved rows
//        if let moved = changes.movedRows {
//            for move in moved {
//                tableView.deleteRows(at: [move.from], with: .fade)
//                tableView.insertRows(at: [move.to], with: .fade)
//            }
//        }
//        
//        tableView.endUpdates()
//        
//        let difference = Date().timeIntervalSince(willBeginChangingContentTime)
//        print("End: \(difference)")
//    }
//    
//    
//}
