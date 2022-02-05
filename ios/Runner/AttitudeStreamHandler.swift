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
    
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        
        if APP.isDeviceMotionAvailable{
            APP.startDeviceMotionUpdates(to: queue) { (data, error) in
                if data != nil {
                    //get attitude
                    //create a dict for attitude pitch, roll and yaw.
                    var attitudeDict = ["pitch":data?.attitude.pitch, "roll":data?.attitude.roll, "yaw":data?.attitude.yaw]
                    events(attitudeDict)
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
