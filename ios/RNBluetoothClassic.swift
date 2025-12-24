//
//  RNBluetoothClassic.swift
//  RNBluetoothClassic
//
//  Created by Ken Davidson on 2019-06-17.
//  Copyright © 2019 Facebook. All rights reserved.
//

import Foundation
import CoreBluetooth
import MediaPlayer
import AVFoundation

/**
 Implementation of the RNBluetoothClassic React Native module.  For information on how this
 module was created and developed see the following:
 
 - https://facebook.github.io/react-native/docs/native-modules-setup
 - https://facebook.github.io/react-native/docs/native-modules-ios
 
 or the README.md located in the parent (Javascript) project.
 
 RNBluetoothClassic is responsible for interacting with the ExternalAccessory framework
 and providing wrappers for listing, connecting, reading, writing, etc.  The actual
 communication has been handed off to the BluetoothDevice class - allowing (in the future)
 more that one BluetoothDevice to be connected at one time.
 
 Currently the module communicates using Base64 .utf8 encoded strings.  This should
 be updated in the future to use [UInt8] to match the communication on the
 BluetoothDevice side.  This means that the responsiblity of converting and managing
 data is done in Javascript/client rather than in the module.
 */
@objc(RNBluetoothClassic)
class RNBluetoothClassic : NSObject, RCTBridgeModule {
    private var listeners: Dictionary<String,Int>
    var centralManager: CBCentralManager!
    
    static func moduleName() -> String! {
        return "RNBluetoothClassic"
    }
    
    @objc var bridge: RCTBridge!

    /**
    *  By default, initialize CBCentralManager when bluetooth is not available prompts
    *  "Turn On Bluetooth to Allow [app name] to Connect to Accessories" dialog.
    *  See CBCentralManagerOptionShowPowerAlertKey for more details about this behavior
    *
    *  By using Lazy initialization on CBCentralManager it will prompt bluetooth permission
    *  on first call of any bluetooth-related method.
    */
    private lazy var cbCentral: CBCentralManager = CBCentralManager()
    
    /**
     * Initializes the RNBluetoothClassic module.  At this point it's not quite as customizable as the
     * Java version, but I'm slowly working on figuring out how to incorporate the same logic in a
     * Swify way, but my ObjC and Swift is not strong, very very not strong.
     */
    override init() {
        self.listeners = Dictionary()
        super.init()
        setupNotifications()
    }
    
    private func setupNotifications() {
        // 注册路由改变通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: NSNotification.Name.AVAudioSessionRouteChange,
            object: AVAudioSession.sharedInstance()
        )
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        // 打印改变的原因
        switch reason {
            case .newDeviceAvailable: // 蓝牙连接或耳机插入
                print("检测到新音频设备已连接")
                let route = AVAudioSession.sharedInstance().currentRoute
                processRoute(route)
                
            case .oldDeviceUnavailable: // 蓝牙断开或耳机拔出
                sendEvent(EventType.AUDIO_CHANGE.name, body: [])
                
            case .categoryChange: // AVAudioSession 类别改变
                print("Session Category 改变")
                
            default:
                break
        }
    }
    
    private func processRoute(_ route: AVAudioSessionRouteDescription) {
        for output in route.outputs {
            sendEvent(EventType.AUDIO_CHANGE.name, body: [
                "uid": output.uid,
                "portName": output.portName
            ])
        }
    }
    
   @objc
   func getCurrentRoute(
       _ resolve: RCTPromiseResolveBlock,
       rejecter reject: RCTPromiseRejectBlock
   ) -> Void {
       let currentRoute = AVAudioSession.sharedInstance().currentRoute
       for output in currentRoute.outputs {
           resolve([
            "uid": output.uid,
            "portName": output.portName
           ])
       }
   }
    
    /**
     * Whether or not bluetooth is currently enabled - currently this is done by using the
     * CoreBluetooth (BLE) framework, as it should hopefully be good enough for performing
     * bluetooth system tasks.
     * - parameter resolver: resovles with true|false based on enable
     * - parameter reject: should never be rejected
     */
    @objc
    func isBluetoothEnabled(
        _ resolve: RCTPromiseResolveBlock,
        rejecter reject: RCTPromiseRejectBlock
    ) -> Void {
        resolve(checkBluetoothAdapter())
    }
    
    /**
     * Check the Core Bluetooth Central Manager for status
     */
    private func checkBluetoothAdapter() -> Bool {
        var enabled = false
        
        if #available(iOS 10.0, *) {
            enabled = (cbCentral.state == CBManagerState.poweredOn)
        } else {
            enabled = (cbCentral.state.rawValue == CBCentralManagerState.poweredOn.rawValue)
        }
        
        return enabled
    }
    
    var isControl = true
    
    @objc
    func sendLyrics(_ lrc: String) {
        if (isControl) {
            isControl = false;
            let commandCenter = MPRemoteCommandCenter.shared()
            
            commandCenter.playCommand.removeTarget(LockScreenPlay)
            commandCenter.playCommand.addTarget(handler: LockScreenPlay)
            
            commandCenter.pauseCommand.removeTarget(LockScreenPause)
            commandCenter.pauseCommand.addTarget(handler: LockScreenPause)
            
            commandCenter.nextTrackCommand.removeTarget(LockScreenNext)
            commandCenter.nextTrackCommand.addTarget(handler: LockScreenNext)
            
            commandCenter.previousTrackCommand.removeTarget(LockScreenPrev)
            commandCenter.previousTrackCommand.addTarget(handler: LockScreenPrev)
        }
        
        let infoCenter = MPNowPlayingInfoCenter.default()
        var nowPlayingInfo = [String: Any]()

        // 关键技巧：为了让车机感知到变化，有些开发者会将歌词放在 Title
        // 或者专门的歌词字段（如果目标设备支持 AVRCP 1.6+）
        nowPlayingInfo[MPMediaItemPropertyTitle] = lrc
        
        // 必须设置播放速率和时间，否则部分车机不会刷新显示
//        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
//        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 5
//        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 200

        infoCenter.nowPlayingInfo = nowPlayingInfo
    }
    
    private func LockScreenPlay(arg: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        sendEvent(EventType.DEVICE_ACTION.name, body: [
            "action": "play"
        ])
        return .success
    }
    
    private func LockScreenPause(arg: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        sendEvent(EventType.DEVICE_ACTION.name, body: [
            "action": "pause"
        ])
        return .success
    }
    
    private func LockScreenNext(arg: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        sendEvent(EventType.DEVICE_ACTION.name, body: [
            "action": "next"
        ])
        return .success
    }
    
    private func LockScreenPrev(arg: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        sendEvent(EventType.DEVICE_ACTION.name, body: [
            "action": "prev"
        ])
        return .success
    }
    
    
    func sendEvent(_ eventName: String, body: Any?) {
         guard let bridge = self.bridge else {
             NSLog("Error when sending event \(eventName) with body \(body ?? ""); Bridge not set")
             return
         }
         
         guard (listeners[eventName] != nil || listeners[eventName] == 0) else {
             NSLog("Sending '%@' with no listeners registered; was skipped", eventName)
             return
         }
         
         var data: [Any] = [eventName]
         if let actualBody = body {
             data.append(actualBody)
         }
         
         bridge.enqueueJSCall("RCTDeviceEventEmitter",
                              method: "emit",
                              args: data,
                              completion: nil)
     }
     
     @objc
     func addListener(
        _ requestedEvent: String
     ) {
        var eventName = requestedEvent
        var deviceId: String?
         
        if (requestedEvent.contains("@")) {
            let split = requestedEvent.split(separator: "@")
            eventName = String(split[0])
            deviceId = String(split[1])
        }
         
        guard EventType.allCases.firstIndex(where: { $0.name == eventName}) ?? -1 >= 0 else {
            NSLog("%@ is not a supported EventType", eventName)
            return
        }
         
        // When saving the listener, we need to use the requested event now that we know
        // it's legal, this way we maintain the DEVICE_READ@<serialNumber>
        let listenerCount = listeners[requestedEvent] ?? 0
        listeners[requestedEvent] = listenerCount + 1
     }
     
    @objc
    func removeListener(_ requestedEvent: String) {
        var eventName = requestedEvent
        var eventDevice: String?
         
        if (requestedEvent.contains("@")) {
            let split = requestedEvent.split(separator: "@")
            eventName = String(split[0])
            eventDevice = String(split[1])
        }
         
        guard EventType.allCases.firstIndex(where: { $0.name == eventName}) ?? -1 >= 0 else {
            NSLog("%@ is not a supported EventType", eventName)
            return
        }
         
        let listenerCount = listeners[eventName] ?? 0
         
        if listenerCount > 0 {
            listeners[eventName] = listenerCount - 1
        }
    }
     
    @objc
    func removeAllListeners(_ requestedEvent: String) {
        var eventName = requestedEvent
        var eventDevice: String?
        
        if (requestedEvent.contains("@")) {
            let split = requestedEvent.split(separator: "@")
            eventName = String(split[0])
            eventDevice = String(split[1])
        }
         
        guard EventType.allCases.firstIndex(where: { $0.name == eventName}) ?? -1 >= 0 else {
            NSLog("%@ is not a supported EventType", eventName)
            return
        }
         
        let listenerCount = listeners[eventName] ?? 0
         
        if listenerCount > 0 {
            listeners[eventName] = listenerCount - 1
        }

    }
    
}
