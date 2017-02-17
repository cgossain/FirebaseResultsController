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
    
    fileprivate let dateCellIdentifier = "dateCellIdentifier"
    
    lazy var root = FIRDatabase.database().reference().child("dates")
    
    lazy var resultsController: FirebaseResultsController = {
        let query = self.root.queryOrderedByKey()
        
        let fetchRequest = FirebaseFetchRequest(query: query)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        let controller = FirebaseResultsController(fetchRequest: fetchRequest, sectionNameKeyPath: "category")
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
        resultsController.performFetch()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func addButtonTapped(_ sender: UIBarButtonItem) {
        let date = randomDate()
        root.childByAutoId().setValue(["date": date.timeIntervalSinceReferenceDate,
                                       "category": randomCategory()])
    }
    
    func randomDate() -> Date {
        let offset = Int(arc4random_uniform(7)) // random day offset from 0 and 6
        let calendar = Calendar.current
        let randomDate = calendar.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return randomDate
    }
    
    func randomCategory() -> Int {
        return Int(arc4random_uniform(4))
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return resultsController.sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return resultsController.sections[section].numberOfObjects
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: dateCellIdentifier, for: indexPath)
        
        let snapshot = try! resultsController.object(at: indexPath)
        if let timeInterval = (snapshot.value as? [String: Any])?["date"] as? Double {
            cell.textLabel?.text = dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: timeInterval))
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return resultsController.sections[section].name
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let delete = UITableViewRowAction(style: .destructive, title: "Delete") { (action, path) in
            let snapshot = try! self.resultsController.object(at: indexPath)
            snapshot.ref.removeValue()
        }
        return [delete]
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // print the snapshot description
        let snapshot = try! resultsController.object(at: indexPath)
        print("Snapshot: \(snapshot)")
        
        // make sure the controller is spitting back the correct path
        let path = resultsController.indexPath(for: snapshot)
        print("Controller Path: \(path)")
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension ViewController: FirebaseResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: FirebaseResultsController) {
        
    }
    
    func controllerDidChangeContent(_ controller: FirebaseResultsController) {
        tableView.reloadData()
    }
    
}
