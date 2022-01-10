# phonetowers

A new Flutter application.

https://github.com/bradrushworth/aus_phone_towers_iphone

## Getting Started

To use Cocopods on Windows: https://airtdave.medium.com/using-cocoapods-on-windows-dec471735f51

cd ios
gem install cocoapods -v 1.10.1
pod --version
1.10.1

You must use 1.10.1 because 1.11.* will be broken on Windows.

cd ios
flutter clean
flutter pub get
pod install




#import the xcodeproj ruby gem
require 'xcodeproj'
#define the path to your .xcodeproj file
project_path = 'ios/Runner.xcodeproj'
#open the xcode project
project = Xcodeproj::Project.open(project_path)
#find the group on which you want to add the file
group = project.main_group["Runner"]["Runner"]
#get the file reference for the file to add
file = group.new_file("Runner.swift")
#add the file reference to the projects first target
main_target = project.targets.first
main_target.add_file_references([file])
#finally, save the project
project.save



    While building module 'firebase_core' imported from /Users/builder/programs/flutter_2_8_1/.pub-cache/hosted/pub.dartlang.org/firebase_crashlytics-2.4.5/ios/Classes/FLTFirebaseCrashlyticsPlugin.h:12:
    In file included from <module-includes>:1:
    In file included from /Users/builder/clone/ios/Pods/Target Support Files/firebase_core/firebase_core-umbrella.h:13:
    In file included from /Users/builder/programs/flutter_2_8_1/.pub-cache/hosted/pub.dartlang.org/firebase_core-1.11.0/ios/Classes/FLTFirebaseCorePlugin.h:12:
    /Users/builder/programs/flutter_2_8_1/.pub-cache/hosted/pub.dartlang.org/firebase_core-1.11.0/ios/Classes/FLTFirebasePlugin.h:9:9: error: include of non-modular header inside framework module 'firebase_core.FLTFirebasePlugin': '/Users/builder/clone/ios/Pods/Headers/Public/FirebaseCore/FirebaseCore.h' [-Werror,-Wnon-modular-include-in-framework-module]
    #import <FirebaseCore/FirebaseCore.h>
            ^
    1 error generated.
    In file included from /Users/builder/programs/flutter_2_8_1/.pub-cache/hosted/pub.dartlang.org/firebase_crashlytics-2.4.5/ios/Classes/FLTFirebaseCrashlyticsPlugin.m:5:
    /Users/builder/programs/flutter_2_8_1/.pub-cache/hosted/pub.dartlang.org/firebase_crashlytics-2.4.5/ios/Classes/FLTFirebaseCrashlyticsPlugin.h:12:9: fatal error: could not build module 'firebase_core'
    #import <firebase_core/FLTFirebasePlugin.h>
     ~~~~~~~^
    2 errors generated.
