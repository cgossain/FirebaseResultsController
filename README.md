# FirebaseResultsController
[![CI Status](http://img.shields.io/travis/cgossain@gmail.com/FirebaseResultsController.svg?style=flat)](https://travis-ci.org/cgossain@gmail.com/FirebaseResultsController)
[![Version](https://img.shields.io/cocoapods/v/FirebaseResultsController.svg?style=flat)](http://cocoapods.org/pods/FirebaseResultsController)
[![License](https://img.shields.io/cocoapods/l/FirebaseResultsController.svg?style=flat)](http://cocoapods.org/pods/FirebaseResultsController)
[![Platform](https://img.shields.io/cocoapods/p/FirebaseResultsController.svg?style=flat)](http://cocoapods.org/pods/FirebaseResultsController)

FirebaseResultsController is a controller used to manage the results of a query attached to a Firebase Realtime Database.

It offers additional filtering and sorting capabilities, diffing support (using LCS algoritm), and realtime content updates. These features come together to facilitate building data driven UITableView's.

## Example

This project includes a simple demo application that demonstrates how to use a FirebaseResultsController to power an instance of UITableView.

### Prerequisites

To run the example project, clone the repo, and run `pod install` from the Example directory first.

You'll also need to create a Firebase account, and follow the instructions to create a demo project. Once your demo project has been created in your Firebase account, you'll need to download the project's corresponding `GoogleService-Info.plist` and add it the demo project. The Firebase framework automatically detects this file when the app launches, and will configure the environment accordingly.

P.S You can just copy your `GoogleService-Info.plist` directly to the `Example/FirebaseResultsController/` directory, and the Xcode project should automatically pick it up.

## Installation

FirebaseResultsController is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "FirebaseResultsController"
```

## Usage Instructions

### FirebaseFetchRequest
To describe a fetch operation, you need to first create a FirebaseFetchRequest. You create a FirebaseFetchRequest with a Firebase DatabaseQuery instance. A DatabaseQuery already provides support for filtering and sorting, but only to a certain extent. If the built in behaviour is not enough, you can specify an NSPredicate, and an array of NSSortDescriptor's that can be applied to the final fetched data.

```
let query: DatabaseQuery = ...      // some Firebase query

let fetchRequest = FirebaseFetchRequest(query: query)
fetchRequest.predicate = ...        // optional NSPredicate that is applied to fetched data
fetchRequest.sortDescriptors = ...  // optional array of NSSortDescriptor's applied to fetched data
```

### FirebaseResultsController
The FirebaseResultsController is the main class used to fetch the data. You create it with a FirebaseFetchRequest, and optionally a `sectionNameKeyPath` on result objects that returns the section name.

```
let controller = FirebaseResultsController(fetchRequest: fetchRequest, sectionNameKeyPath: <optional key path>)
```

You must call `performFetch()` at least once to begin receiving data. Afterwards, if you change the predicate or sort descriptors on the controller's fetch request, you must call `performFetch()` again (i.e. filtering via a search bar).
```
controller.fetchRequest.predicate = ...         // updated predicate
controller.fetchRequest.sortDescriptors = ...   // updated sort descriptors

controller.performFetch()                       // reconfigures the controller for the updated fetch request
```

Calling `performFetch()` will attach observers for the specified database query. This automatically provides realtime updates to the controller's content. To enabled diffing these realtime updates, you need to specify a `changeTracker` which is an object that conforms to the `FirebaseResultsControllerChangeTracking` protocol.
```
controller.changeTracker = ... // object that conforms to FirebaseResultsControllerChangeTracking
```

For Example:
```
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
```

### Composing Results (Beta)
You can use the ComposedFirebaseResultsController to compose multiple FirebaseResultsController together.
```
let controller1 = FirebaseResultsController(fetchRequest: fetchRequest1, sectionNameKeyPath: <optional key path>)
let controller2 = FirebaseResultsController(fetchRequest: fetchRequest2, sectionNameKeyPath: <optional key path>)
let controller3 = FirebaseResultsController(fetchRequest: fetchRequest3, sectionNameKeyPath: <optional key path>)

let controllers = [controller1, controller2, controller3]

let composedResultsController = ComposedFirebaseResultsController(controllers: controllers, composedQuery: <optional composed query>)
```

The ComposedFirebaseResultsController maps index paths between the internal controllers and the external aggregated results. It also exposes a similar API to the FirebaseResultsController.


## Contribution

Create a fork of the project into your own repository. Make all your necessary changes and create a pull request with a description on what was added or removed and details explaining the changes in lines of code. If approved, project owners will merge it.


## Author

Christian Gossain, cgossain@gmail.com

## License

FirebaseResultsController is released under the MIT license. See [LICENSE](https://github.com/cgossain/FirebaseResultsController/blob/master/LICENSE) for details.
