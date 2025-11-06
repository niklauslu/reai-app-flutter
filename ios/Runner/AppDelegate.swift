import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    print("✅ ReAI Assistant iOS应用已启动")

    return true
  }

  // 应用进入后台
  override func applicationDidEnterBackground(_ application: UIApplication) {
    print("🍎 应用进入后台")
  }

  // 应用回到前台
  override func applicationWillEnterForeground(_ application: UIApplication) {
    print("🍎 应用回到前台")
  }

  // 应用即将终止
  override func applicationWillTerminate(_ application: UIApplication) {
    print("🍎 应用即将终止")
  }
}