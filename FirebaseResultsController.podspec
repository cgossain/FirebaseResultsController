Pod::Spec.new do |s|
  s.name             = 'FirebaseResultsController'
  s.version          = '1.0.3'
  s.summary          = 'An NSFetchedResultsController replacement for Firebase, written in Swift.'
  s.description      = <<-DESC
                        The FirebaseResultsController is an NSFetchedResultsController replacement that allows you to monitor (fetch, filter, sort, section, and diff) data stored in a Firebase Realtime Database.

                        The controller has a similar interface to NSFetchedResultsController, and can be used to drive UI backed by UITableView or UICollectionView.
                       DESC
  s.homepage         = 'https://github.com/cgossain/FirebaseResultsController'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Christian Gossain' => 'cgossain@gmail.com' }
  s.source           = { :git => 'https://github.com/cgossain/FirebaseResultsController.git', :tag => s.version.to_s }
  s.swift_versions   = ['5.0']
  s.ios.deployment_target = '11.4'
  s.static_framework = true
  s.source_files = 'FirebaseResultsController/Classes/**/*'
  s.dependency 'Dwifft', '~> 0.9'
  s.dependency 'Firebase/Core'
  s.dependency 'Firebase/Database'
  s.dependency 'Debounce'
end
