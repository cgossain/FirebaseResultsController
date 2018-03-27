Pod::Spec.new do |s|
  s.name             = 'FirebaseResultsController'
  s.version          = '0.1.0'
  s.summary          = 'An NSFetchedResultsController replacement for Firebase, written in Swift.'
  s.description      = <<-DESC
                        The FirebaseResultsController is an NSFetchedResultsController replacement that allows you to monitor (fetch, filter, sort, section, and diff) data stored in a Firebase Realtime Database.

                        The controller follows a similar interface to NSFetchedResultsController, which can be used to drive UITableView or UICollectionView's.
                       DESC
  s.homepage         = 'https://github.com/cgossain/FirebaseResultsController'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Christian Gossain' => 'cgossain@gmail.com' }
  s.source           = { :git => 'https://github.com/cgossain/FirebaseResultsController.git', :tag => s.version.to_s }
  s.module_name = 'FirebaseResultsController'
  s.swift_version = '4.0'
  s.static_framework = true

  s.ios.deployment_target = '9.0'

  s.source_files = 'FirebaseResultsController/Classes/**/*'

  s.dependency 'Dwifft', '0.5'
  s.dependency 'Firebase/Database'
end
