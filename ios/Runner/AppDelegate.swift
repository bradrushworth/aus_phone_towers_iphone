import UIKit
import Flutter
import GoogleMaps
import Firebase
import MessageUI

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, MFMailComposeViewControllerDelegate {

  static let screenshotChannelName = "au.com.bitbot.phonetowers.flutter.provider/screenshot"
  let defaultSubject = "Aus Phone Towers Problem Report"
  let reportBody = "Describe the problem..."
  let reportRecipient = "bitbot@bitbot.com.au"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    //FirebaseApp.configure()

    GMSServices.provideAPIKey("AIzaSyDd_W-tPbI0F8ZRw1T5cAKLobOIfVLotDM")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Under the UIScene life cycle the window and its FlutterViewController do not exist yet in
  // didFinishLaunchingWithOptions. Flutter calls this once the implicit engine exists, and it is
  // the documented place to register plugins and create method channels.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let shareChannel = FlutterMethodChannel(
      name: AppDelegate.screenshotChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    shareChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else {
        result(nil)
        return
      }
      if call.method == "takeScreenshot" {
        // Dart sends {"path": <file name in the temporary directory>, "subject": ...}. Fall back
        // to a default subject / no attachment if the argument shape ever changes.
        let arguments = call.arguments as? [String: Any]
        let subject = (arguments?["subject"] as? String) ?? self.defaultSubject
        let fileName = arguments?["path"] as? String
        self.shareReport(fileName: fileName, subject: subject)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Report a Problem

  /// Finds the screenshot Dart saved. path_provider's temporary directory on iOS is the Caches
  /// directory, so look there as well as in NSTemporaryDirectory(). Only the last path
  /// component of the name is used.
  func screenshotURL(named name: String?) -> URL? {
    guard let name = name else { return nil }
    let fileName = (name as NSString).lastPathComponent
    if fileName.isEmpty { return nil }
    var directories = [URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)]
    directories.append(contentsOf: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask))
    for directory in directories {
      let url = directory.appendingPathComponent(fileName)
      if FileManager.default.fileExists(atPath: url.path) {
        return url
      }
    }
    return nil
  }

  /// The view controller to present from, looked up when needed: the key window's root view
  /// controller of a connected window scene (the foreground one first), then whatever is
  /// presented on top of it.
  func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let ordered = scenes.filter { $0.activationState == .foregroundActive }
      + scenes.filter { $0.activationState != .foregroundActive }
    for scene in ordered {
      let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
      if var top = window?.rootViewController {
        while let presented = top.presentedViewController {
          top = presented
        }
        return top
      }
    }
    return nil
  }

  func shareReport(fileName: String?, subject: String) {
    guard let presenter = topViewController() else {
      print("Report a Problem: no view controller to present from")
      return
    }
    let url = screenshotURL(named: fileName)
    let imageData: Data? = url.flatMap { try? Data(contentsOf: $0) }

    if MFMailComposeViewController.canSendMail() {
      let composer = MFMailComposeViewController()
      composer.mailComposeDelegate = self
      composer.setToRecipients([reportRecipient])
      composer.setSubject(subject)
      composer.setMessageBody(reportBody, isHTML: false)
      if let data = imageData, let url = url {
        composer.addAttachmentData(data, mimeType: "image/png", fileName: url.lastPathComponent)
      }
      presenter.present(composer, animated: true, completion: nil)
      return
    }

    // No Apple Mail account: let the user pick any app (another mail client, Messages, Files...).
    var items: [Any] = [ReportTextItem(subject: subject, body: reportBody)]
    if let data = imageData, let image = UIImage(data: data) {
      items.append(image)
    }
    let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
    if let popover = activity.popoverPresentationController {
      // Required on iPad, where this is shown as a popover.
      popover.sourceView = presenter.view
      popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY,
                                  width: 0, height: 0)
      popover.permittedArrowDirections = []
    }
    presenter.present(activity, animated: true, completion: nil)
  }

  // MARK: - MFMailComposeViewControllerDelegate
  func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
    controller.dismiss(animated: true, completion: nil)
  }
}

/// Carries the report's text and email subject into the share sheet.
final class ReportTextItem: NSObject, UIActivityItemSource {
  private let subject: String
  private let body: String

  init(subject: String, body: String) {
    self.subject = subject
    self.body = body
  }

  func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
    return body
  }

  func activityViewController(_ activityViewController: UIActivityViewController,
                              itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
    return body
  }

  func activityViewController(_ activityViewController: UIActivityViewController,
                              subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
    return subject
  }
}
