Pod::Spec.new do |s|
  s.name             = 'FirebaseResultsController'
  s.version          = '0.1.0'
  s.summary          = 'An NSFetchedResultsController replacement for Firebase, written in Swift.'
  s.description      = <<-DESC
                        The FirebaseResultsController is an NSFetchedResultsController replacement that allows you to monitor (fetch, filter, sort, section, and diff) data stored in a Firebase realtime database.

                        The controller follows an identical interface as NSFetchedResultsController, which can be used to power your UI. The controller can also diff changes as they occur live, allowing you to perform barch updates on UITableView and UICollectionView.
                       DESC
  s.homepage         = 'https://github.com/cgossain@gmail.com/FirebaseResultsController'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Christian Gossain' => 'cgossain@gmail.com' }
  s.source           = { :git => 'https://github.com/cgossain@gmail.com/FirebaseResultsController.git', :tag => s.version.to_s }
  s.ios.deployment_target = '9.0'
  s.source_files = 'FirebaseResultsController/Classes/**/*'
  s.dependency 'Dwifft', '0.5'

  # Specify what libraries this depends on.
  s.libraries = [
    'c++',                  # FirebaseAnalytics.
    'icucore',              # FirebaseDatabase.
    'sqlite3',              # FirebaseAnalytics.
    'z',                    # FirebaseAnalytics.
  ]

  # Specify what frameworks this depends on.
  s.frameworks = [
    'AddressBook',          # FirebaseAnalytics.
    'AdSupport',            # FirebaseAnalytics.
    'CFNetwork',            # FirebaseDatabase.
    'SafariServices',       # FirebaseAnalytics.
    'Security',             # FirebaseAnalytics, FirebaseAuth, FirebaseDatabase.
    'StoreKit',             # FirebaseAnalytics.
    'SystemConfiguration',  # FirebaseAnalytics, FirebaseDatabase.
  ]

  # Specify the frameworks we are providing.
  # The app using this Pod should _not_ link these Frameworks,
  # they are bundled as a part of this Pod for technical reasons.
  s.vendored_frameworks = 'FirebaseResultsController/Frameworks/**/*.framework'

  # LDFLAGS required by Firebase dependencies.
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
  }

end
