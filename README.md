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

