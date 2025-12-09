//
//  RNBluetoothClassic.swift
//  RNBluetoothClassic
//
//  Created by Ken Davidson on 2019-06-17.
//  Copyright © 2019 Facebook. All rights reserved.
//

import Foundation
import CoreBluetooth

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
}
