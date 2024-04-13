import UIKit
import Flutter
import workmanager

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    WorkmanagerPlugin.registerBGProcessingTask(withIdentifier: "auto-upload-photos")
    // Run background sync every 2 hours
    WorkmanagerPlugin.registerPeriodicTask(withIdentifier: "com.bewcloud.mobile.iOSBackgroundAppRefresh", frequency: NSNumber(value: 2 * 60 * 60))
    UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(2 * 60 * 60))
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
