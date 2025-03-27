import UIKit
import Flutter
import workmanager
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
          if let error = error {
              print("Notification permission error: \(error)")
          }
      }
    }

    WorkmanagerPlugin.registerTask(withIdentifier: "auto-upload-photos")
    WorkmanagerPlugin.registerTask(withIdentifier: "com.bewcloud.mobile.iOSBackgroundAppRefresh")
    WorkmanagerPlugin.registerTask(withIdentifier: "workmanager.background.task")
      
    // WorkmanagerPlugin.registerBGProcessingTask(withIdentifier: "auto-upload-photos")
    // Run background sync every 2 hours
    // WorkmanagerPlugin.registerPeriodicTask(withIdentifier: "com.bewcloud.mobile.iOSBackgroundAppRefresh", frequency: NSNumber(value: 2 * 60 * 60))
    UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(2 * 60 * 60))
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
