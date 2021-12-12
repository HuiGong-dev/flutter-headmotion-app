//
//  AttitudeStreamHandler.swift
//  Runner
//
//  Created by Hui Gong on 12.12.21.
//

import Foundation
import CoreMotion
import UIKit

class AttitudeStreamHandler : NSObject, FlutterStreamHandler {
    let APP = CMHeadphoneMotionManager()
    private let queue = OperationQueue()
    
//    APP.delegate = self
    
//    guard APP.isDeviceMotionAvailable else {
//        self.Alert("Sorry", "Your device is not supported.")
//        UITextView.text = "Sorry, Your device is not supported."
//        return
//    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        
        if APP.isDeviceMotionAvailable{
            APP.startDeviceMotionUpdates(to: queue) { (data, error) in
                if data != nil {
                    //get attitude roll
                    let attitudeRoll = data?.attitude.roll
                    events(attitudeRoll)
                }
                
            }
        } 
        return nil
        
    }
    
    func onCancel(withArguments arguments:Any?) -> FlutterError? {
        APP.stopDeviceMotionUpdates()
        return nil
    }
}
