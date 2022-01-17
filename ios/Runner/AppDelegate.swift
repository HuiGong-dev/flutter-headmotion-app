import UIKit
import Flutter
import CoreMotion

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      
      let METHOD_CHANNEL_NAME = "com.huigong.headmotion/method"
      let ATTITUDE_CHANNEL_NAME = "com.huigong.headmotion/attitude"
      let attitudeStreamHandler = AttitudeStreamHandler()
      
      let controller : FlutterViewController  = window?.rootViewController as! FlutterViewController
      
      let methodChannel = FlutterMethodChannel(name: METHOD_CHANNEL_NAME, binaryMessenger: controller.binaryMessenger)
      
      methodChannel.setMethodCallHandler({
          (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
          switch call.method {
          case "isSensorAvailable":
              result(CMHeadphoneMotionManager().isDeviceMotionAvailable)
          case "isDeviceMotionActive":
              result(CMHeadphoneMotionManager().isDeviceMotionActive)    
          default:
              result(FlutterMethodNotImplemented)
          }
      })
      
      let attitudeChannel = FlutterEventChannel(name: ATTITUDE_CHANNEL_NAME, binaryMessenger: controller.binaryMessenger)
      attitudeChannel.setStreamHandler(attitudeStreamHandler )
      
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
