//
//  AuthManagerBridgeGlobal.m
//  Unity-iPhone
//
//  Created by Admin on 8/5/25.
//

#import "AuthManagerBridgeGlobal.h"
#import <UnityFramework/UnityFramework-Swift.h>

AuthManagerObjCBridge *GlobalAuthManagerBridge(void) {
    static AuthManagerObjCBridge *bridge = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bridge = [[AuthManagerObjCBridge alloc] init];
    });
    return bridge;
}
