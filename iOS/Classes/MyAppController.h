//
//  MyAppController.h
//  Unity-iPhone
//
//  Created by Admin on 8/3/25.
//

#import <UnityFramework/UnityFramework.h>
#import <UnityFramework/UnityAppController.h>
#import <MenuDialogViewController.h>

#ifndef MyAppController_h
#define MyAppController_h

@interface MyAppController : UnityAppController
typedef void ( * OnCallback ) ( const char* object );
@end

@interface MyAppController () <AuthResultDelegate>

@end

#endif /* MyAppController_h */

#ifdef __cplusplus
extern "C" {
#endif

void startSDK(id<AuthResultDelegate> delegate);

void KKSOFT_Initialize(UIViewController *unityVC, OnCallback onCallback );

void KKSOFT_Auth();

void KKSOFT_TokenExpiration();

void KKSOFT_ServerMaintainance();

#ifdef __cplusplus
}
#endif
