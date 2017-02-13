Pod::Spec.new do |s|
  s.name             = 'FirebaseResultsController'
  s.version          = '0.1.0'
  s.summary          = 'A controller to manage data stored in a Firebase database reference.'
  s.description      = <<-DESC
  The FirebaseResultsController is a controller object used to retrive, manage, and monitor data stored in a Firebase database reference. The controller offers an almost identical interface as NSFetchedResultsController.

  FirebaseResultsController supports fetching, sorting, filtering, and sectionning Firebase data, to easily back a UITableView.
                       DESC
  s.homepage         = 'https://github.com/cgossain@gmail.com/FirebaseResultsController'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'cgossain@gmail.com' => 'cgossain@gmail.com' }
  s.source           = { :git => 'https://github.com/cgossain@gmail.com/FirebaseResultsController.git', :tag => s.version.to_s }
  s.ios.deployment_target = '9.3'
  s.source_files = 'FirebaseResultsController/Classes/**/*'

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
  s.vendored_frameworks = [
    'FirebaseResultsController/Frameworks/Firebase/Analytics/*.framework',
    'FirebaseResultsController/Frameworks/Firebase/Database/*.framework',
  ]

  # LDFLAGS required by Firebase dependencies.
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
  }
end
