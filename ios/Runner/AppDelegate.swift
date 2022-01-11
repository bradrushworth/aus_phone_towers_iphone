import UIKit
import Flutter
import GoogleMaps
import Firebase
import MessageUI

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate,MFMailComposeViewControllerDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyDd_W-tPbI0F8ZRw1T5cAKLobOIfVLotDM")
    GeneratedPluginRegistrant.register(with: self)
    let shareChannelName = "au.com.bitbot.phonetowers/screenshot";
    let controller:FlutterViewController = self.window?.rootViewController as! FlutterViewController;
    let shareChannel:FlutterMethodChannel = FlutterMethodChannel.init(name: shareChannelName, binaryMessenger: controller as! FlutterBinaryMessenger);
    
    shareChannel.setMethodCallHandler({
        (call: FlutterMethodCall, result: FlutterResult) -> Void in
        if (call.method == "takeScreenshot") {
            self.shareFile(sharedItems: call.arguments!,controller: controller);
        }
    });
    
    // ------------------
    if FirebaseApp.app() == nil {
        FirebaseApp.configure()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func shareFile(sharedItems:Any, controller:UIViewController) {
        let mailComposeViewController = configureMailComposer()
        if MFMailComposeViewController.canSendMail(){
            controller.present(mailComposeViewController, animated: true, completion: nil)
        }else{
            print("Can't send email")
            
            let alert = UIAlertController(title: "Can't send mail", message: "Please configure mail app", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler:{ (UIAlertAction)in
                print("User click Ok button")
            }))
            controller.present(alert, animated: true, completion: {
            })
        }
        
        return;
//        let filePath:NSMutableString = NSMutableString.init(string: sharedItems as! String);
//        let docsPath:NSString = (NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0]) as NSString;
//        let imagePath = docsPath.appendingPathComponent(filePath as String);
//        let imageUrl = URL.init(fileURLWithPath: imagePath, relativeTo: nil);
//        do {
//            let imageData = try Data.init(contentsOf: imageUrl);
//            let shareImage = UIImage.init(data: imageData);
//            let activityViewController:UIActivityViewController = UIActivityViewController.init(activityItems: [shareImage!], applicationActivities: nil);
//            controller.present(activityViewController, animated: true, completion: nil);
//        } catch let error {
//            print(error.localizedDescription);
//
//        }
    }
    func configureMailComposer() -> MFMailComposeViewController{
        let mailComposeVC = MFMailComposeViewController()
        mailComposeVC.mailComposeDelegate = self
        mailComposeVC.setToRecipients(["bitbot@bitbot.com.au"])
        mailComposeVC.setSubject("Aus Phone Towers Problem Report")
        mailComposeVC.setMessageBody("Please attach your screenshot, describe the problem and Brad will get back to you...", isHTML: false)
        return mailComposeVC
    }
    
    //MARK: - MFMail compose method
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}
