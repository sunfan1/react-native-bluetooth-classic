//
//  RNBluetoothClassic.m
//  RNBluetoothClassic
//
//  Created by Ken Davidson on 2019-06-17.
//  Copyright © 2019 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "React/RCTBridgeModule.h"
#import "React/RCTEventEmitter.h"

/**
 * Exports the RNBluetoothClassic native module to the RCTBridge.  RCT_EXTERN_MODULE is required
 * due to the project being developed in Swift.  I'm debating re-writing this module in Objective C, as there
 * are definite pros (from the time I started this) in not attempting to bridge the language gap.
 *
 * @author kendavidson
 */
@interface RCT_EXTERN_MODULE(RNBluetoothClassic, NSObject)

/**
 * Determine whether bluetooth is enabled on the device.  This is based on the Bluetooth manager
 * state (also on the version of IOS on which the app is being run).  This should always resolve
 * true|false and never be rejected
 *
 * @param resolver resolves the promise with true|false
 * @param rejecter rejects the promise - should never occur
 */
RCT_EXTERN_METHOD(isBluetoothEnabled: (RCTPromiseResolveBlock)resolver
                  rejecter: (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(sendLyrics:(NSDictionary *)params)

RCT_EXTERN_METHOD(getCurrentRoute: (RCTPromiseResolveBlock)resolver
                  rejecter: (RCTPromiseRejectBlock)reject)

/**
* Adds a listener to the module.  Listeners can be generic: connect, disconnect, etc. or they can
* be device specific read@AA:BB:CC:DD:EE.  Adding a listener will increment a counter
* keyed on the provided eventType
*/
RCT_EXTERN_METHOD(addListener: (NSString *)requestedEvent)

/**
* Remove a specified listener.  LIke addListener this can be generic or device specific
*/
RCT_EXTERN_METHOD(removeListener: (NSString *)requestedEvent)

/**
* Removes all listeners of this type.  This sets the counter to 0 (stopping all messages from
* being sent to React Native).
*/
RCT_EXTERN_METHOD(removeAllListeners: (NSString *)requestedEvent)

@end
