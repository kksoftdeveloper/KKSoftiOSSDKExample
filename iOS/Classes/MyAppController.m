//
//  MyAppController.m
//  UnityFramework
//
//  Created by Admin on 8/3/25.
//
#import <UnityFramework/UnityFramework.h>
#import <UnityFramework/UnityFramework-Swift.h>
#import <UnityFramework/UnityAppController.h>
#import "MyAppController.h"
#import "AuthManagerBridgeGlobal.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <GoogleSignIn/GoogleSignIn.h>
#import "Firebase.h"

// Forward declaration for Swift class
@class AuthSessionOutputBridge;

static OnCallback g_callback = NULL;
static KKSOFTProxy *g_proxy = nil;
static BOOL g_kksoftInitialized = NO;

static void KKSOFT_CallbackForwarder(const char *object) {
    if (g_callback) {
        g_callback(object);
    }
}

//NSString *unauthKey = [NotificationKeys UNAUTHENTICATED_TOKEN_KEY];
//NSString *expKey    = [NotificationKeys EXPIRATION_TOKEN_KEY];

@implementation MyAppController

- (void)didLogoutWithData:(id)data {
    NSLog(@"Did Logout");
    // TODO: Add your business here
    [[KeychainManagerObjCBridge shared] clearAuthSession];

}

- (void)didClose {
    NSLog(@"Did Login Close");
    // TODO: Add your business here
}

- (void)didRefreshedTokenWithData:(id)data {
    // TODO: Add your business here
    NSLog(@"Refreshed Token Success");
    if (data != nil) {
        if([data isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)data;
            NSString *accessToken = dict[@"accessToken"];
            NSString *gameUUID = dict[@"gameUID"];
            NSString *serverId = dict[@"serverId"];
            NSString *refreshToken = dict[@"refreshToken"];

            [[KeychainManagerObjCBridge shared] saveAuthSessionDict:dict];

            NSLog(@"Refreshed data saved.");
        }
    } else {
        NSLog(@"Login failed or data is not a dictionary.");
    }
}

- (void)didAuthenticatedWithData:(id)data {
    // TODO: Add your business here
    NSLog(@"Did Login or register Success/Failure");
    if (data != nil) {
        NSString *accessToken = nil; // Declare it first
        if([data isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)data;
            accessToken = (NSString *)dict[@"accessToken"];
            NSString *gameUUID = dict[@"gameUID"];
            NSString *serverId = dict[@"serverId"];
            NSString *refreshToken = dict[@"refreshToken"];

            // Save to keychain
            [[KeychainManagerObjCBridge shared] saveAuthSessionDict:dict];
            NSLog(@"Login data saved.");
        }
        UIViewController *unityVC = self.rootViewController;

        [unityVC dismissViewControllerAnimated:YES completion:^{
            NSBundle *unityFrameworkBundle = [NSBundle bundleForClass:NSClassFromString(@"MenuDialogViewController")];

            MenuDialogViewController *dialog = [[MenuDialogViewController alloc] initWithNibName:@"MenuDialogViewController" bundle:unityFrameworkBundle];
            [dialog updateToken:accessToken];
//            [dialog updateError:@"Error: 2"];
            dialog.modalPresentationStyle = UIModalPresentationOverFullScreen;
            [unityVC presentViewController:dialog animated:YES completion:nil];
        }];
    } else {
        NSLog(@"Login failed or data is not a dictionary.");
    }
}

- (void)didChangedGameServerWithData:(id _Nullable)data {
    NSLog(@"Did Change Game Server");
    // TODO: Add your business here
    if([data isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)data;
        NSString *gameUUID = dict[@"gameUID"];
        NSString *serverId = dict[@"serverId"];

        // TODO: should save the changed serverId and gameUID here
        NSLog(@"Selected Game Server data saved.");
    } else {
        NSLog(@"Selected Game Server data is null.");
    }
}

- (void)didDeactivateAccountWithData:(id _Nullable)data {
    NSLog(@"Did Deactivate Account");
    // TODO: Add your business here
    [[KeychainManagerObjCBridge shared] clearAuthSession];
}

- (void)didGetLatestSessionWithData:(id _Nullable)data {
    NSLog(@"Did Get Latest Session");
    // TODO: Add your business here

    if([data isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)data;
        NSString *accessToken = dict[@"accessToken"];
        NSString *gameUUID = dict[@"gameUID"];
        NSString *serverId = dict[@"serverId"];
        NSString *refreshToken = dict[@"refreshToken"];

        // Save to keychain
        [[KeychainManagerObjCBridge shared] saveAuthSessionDict:dict];
        NSLog(@"Latest session data saved.");
    } else {
        NSLog(@"Latest session data is null.");
    }
}

- (void)didLinkAccountWithData:(id _Nullable)data {
    NSLog(@"Did Link Account");
    // TODO: Add your business here

    if([data isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)data;
        NSString *accessToken = dict[@"accessToken"];
        NSString *gameUUID = dict[@"gameUID"];
        NSString *serverId = dict[@"serverId"];
        NSString *refreshToken = dict[@"refreshToken"];

        // Save to keychain
        [[KeychainManagerObjCBridge shared] saveAuthSessionDict:dict];
        NSLog(@"Link Account data saved.");
    } else {
        NSLog(@"Link Account data is null.");
    }
}

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
    [FontLoaderObjCBridge loadAllFonts];

    // Configure Facebook SDK before lifecycle initialization
    NSString *facebookAppID = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"FacebookAppID"];
    NSString *facebookClientToken = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"FacebookClientToken"];
    [FBSDKSettings.sharedSettings setAppID:facebookAppID];
    [FBSDKSettings.sharedSettings setClientToken:facebookClientToken];
    FBSDKSettings.sharedSettings.autoLogAppEventsEnabled = NO;
    [FBSDKSettings.sharedSettings enableLoggingBehavior:FBSDKLoggingBehaviorDeveloperErrors];
    [[FBSDKApplicationDelegate sharedInstance] application:application didFinishLaunchingWithOptions:launchOptions];

    // Configure Google Sign-In explicitly from the active environment
    NSString *googleClientID = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"GIDClientID"];
    if (googleClientID.length > 0) {
        GIDSignIn.sharedInstance.configuration = [[GIDConfiguration alloc] initWithClientID:googleClientID];
    }

    [FIRApp configure];

    // Register notification observers early, before any notifications might be posted
    [self registerNotificationObservers];

    // Call super for Unity init
    BOOL launchResult = [super application:application didFinishLaunchingWithOptions:launchOptions];

    dispatch_async(dispatch_get_main_queue(), ^{
        KKSOFT_Initialize(GetAppController().rootViewController, KKSOFT_CallbackForwarder);
    });

    return launchResult;
}

// iOS 10+ method
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    // Handle social login SDK callbacks
    BOOL handledByGoogle = [GIDSignIn.sharedInstance handleURL:url];
    BOOL handledByFacebook = [[FBSDKApplicationDelegate sharedInstance] application:app openURL:url options:options];
    // Handle Unity by calling super (parent logic)
    BOOL handledByUnity = [super application:app openURL:url options:options];

    // Return YES if any handler handled the URL
    return handledByGoogle || handledByFacebook || handledByUnity;
}

// iOS 9 method
- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    // Handle social login SDK callbacks
    BOOL handledByGoogle = [GIDSignIn.sharedInstance handleURL:url];
    BOOL handledByFacebook = [[FBSDKApplicationDelegate sharedInstance] application:application
                                                                            openURL:url
                                                                  sourceApplication:sourceApplication
                                                                         annotation:annotation];
    // Handle Unity by calling super (parent logic)
    BOOL handledByUnity = [super application:application openURL:url sourceApplication:sourceApplication annotation:annotation];

    // Return YES if any handler handled the URL
    return handledByGoogle || handledByFacebook || handledByUnity;
}

- (void)registerNotificationObservers {
    NSLog(@"[MyAppController] Registering notification observers");

    // Handle In-app notification
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRefreshedToken:)
                                                 name:@"KKSOFT.RefreshedToken"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleUnauthenticated:)
                                                 name:@"KKSOFT.UnauthenticatedToken"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleTokenExpired:)
                                                 name:@"KKSOFT.ExpirationToken"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleServerMaintainance:)
                                                 name:@"KKSOFT.ServerMaintainance"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleIAPSuccess:)
                                                 name:@"KKSOFT.IAP.Success"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleIAPFail:)
                                                 name:@"KKSOFT.IAP.FAIL"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleIAPInvalidSKU:)
                                                 name:@"KKSOFT.IAP.InvalidSKU"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleIAPUserCancel:)
                                                 name:@"KKSOFT.IAP.UserCancel"
                                               object:nil];

    NSLog(@"[MyAppController] Notification observers registered");
}

- (void)applicationDidBecomeActive:(UIApplication*)application
{
    // Call Unity's logic first
    [super applicationDidBecomeActive:application];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_callback) {
            NSDictionary *data = @{
                @"event": @"appDidBecomeActive",
                @"platform": @"iOS",
                @"timestamp": @([[NSDate date] timeIntervalSince1970])
            };
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            g_callback([jsonString UTF8String]); // Call Unity callback

        }
        NSLog(@"KKSOFT appDidBecomeActive event forwarded from MyAppController");
    });
}

// Notification Callback
- (void)handleRefreshedToken:(NSNotification *)note
{
    NSLog(@"[MyAppController] ✅ Received refreshed token notification");
    NSLog(@"[MyAppController] Notification name: %@", note.name);
    NSLog(@"[MyAppController] Notification object: %@", note.object);
    NSLog(@"[MyAppController] Notification userInfo: %@", note.userInfo);

    // Extract AuthSessionOutput from notification object
    // The object is a Swift struct AuthSessionOutput, convert it to NSDictionary
    NSDictionary *authSessionDict = [AuthSessionOutputBridge extractFromNotification:note];

    if (authSessionDict != nil) {
        NSLog(@"[MyAppController] Extracted auth session: %@", authSessionDict);

        // Ensure we're on the main thread for UI/keychain operations
        dispatch_async(dispatch_get_main_queue(), ^{
            // Extract values safely with nil checks
            id accessTokenObj = authSessionDict[@"accessToken"];
            id gameUIDObj = authSessionDict[@"gameUID"];  // Note: Swift uses "gameUID" key
            id refreshTokenObj = authSessionDict[@"refreshToken"];

            NSString *accessToken = nil;
            NSString *gameUID = nil;
            NSString *refreshToken = nil;

            // Safely convert to NSString
            if ([accessTokenObj isKindOfClass:[NSString class]]) {
                accessToken = (NSString *)accessTokenObj;
            } else if ([accessTokenObj isKindOfClass:[NSNumber class]]) {
                accessToken = [(NSNumber *)accessTokenObj stringValue];
            }

            if ([gameUIDObj isKindOfClass:[NSString class]]) {
                gameUID = (NSString *)gameUIDObj;
            } else if ([gameUIDObj isKindOfClass:[NSNumber class]]) {
                gameUID = [(NSNumber *)gameUIDObj stringValue];
            }

            if ([refreshTokenObj isKindOfClass:[NSString class]]) {
                refreshToken = (NSString *)refreshTokenObj;
            } else if ([refreshTokenObj isKindOfClass:[NSNumber class]]) {
                refreshToken = [(NSNumber *)refreshTokenObj stringValue];
            }

            NSLog(@"[MyAppController] Access Token: %@", accessToken);
            NSLog(@"[MyAppController] Game UID: %@", gameUID);
            NSLog(@"[MyAppController] Refresh Token: %@", refreshToken);

            // Save to keychain
            if (accessToken && refreshToken && gameUID) {
                [[KeychainManagerObjCBridge shared] saveAuthSessionDict:authSessionDict];
                NSLog(@"[MyAppController] ✅ Refreshed token data saved successfully.");

                // Call your delegate method if needed
                // [self didRefreshedTokenWithData:authSessionDict];
            } else {
                NSLog(@"[MyAppController] ⚠️ Missing required values - accessToken: %@, refreshToken: %@, gameUID: %@",
                      accessToken != nil ? @"present" : @"nil",
                      refreshToken != nil ? @"present" : @"nil",
                      gameUID != nil ? @"present" : @"nil");
            }
        });
    } else {
        NSLog(@"[MyAppController] Failed to extract AuthSessionOutput from notification");

        // Fallback: try to get from userInfo if it was posted there
        if (note.userInfo != nil && note.userInfo.count > 0) {
            NSDictionary *dict = note.userInfo;
            NSLog(@"[MyAppController] Using userInfo instead: %@", dict);
            [[KeychainManagerObjCBridge shared] saveAuthSessionDict:dict];
        }
    }
}

// Notification Callback
- (void)handleUnauthenticated:(NSNotification *)note
{
    NSLog(@"[MyAppController] Received UNAUTHENTICATED notification: %@", note.userInfo);

    dispatch_async(dispatch_get_main_queue(), ^{
        KKSOFT_Auth();
    });
}

// Notification Callback
- (void)handleTokenExpired:(NSNotification *)note
{
    NSLog(@"[MyAppController] Received TOKEN EXPIRED notification: %@", note.userInfo);

    dispatch_async(dispatch_get_main_queue(), ^{
        KKSOFT_TokenExpiration();
    });
}

// Notification Callback
- (void)handleServerMaintainance:(NSNotification *)note
{
    NSLog(@"[MyAppController] Received SERVER MAINTAINANCE notification: %@", note.userInfo);

    dispatch_async(dispatch_get_main_queue(), ^{
        KKSOFT_ServerMaintainance();
    });
}

- (void)handleIAPSuccess:(NSNotification *)data
{
    NSLog(@"[MyAppController] IAP Success: %@", data);
}

- (void)handleIAPFail:(NSNotification *)data
{
    NSLog(@"[MyAppController] IAP Fail: %@", data);
}

- (void)handleIAPUserCancel:(NSNotification *)data
{
    NSLog(@"[MyAppController] IAP User cancel: %@", data);
}

- (void)handleIAPInvalidSKU:(NSNotification *)data
{
    NSLog(@"[MyAppController] IAP Invalid SKU: %@,", data);
}

// Notification Callback
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"KKSOFT.RefreshedToken"
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"KKSOFT.UnauthenticatedToken"
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"KKSOFT.ExpirationToken"
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"KKSOFT.ServerMaintainance"
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"KKSOFT.IAP.Success"
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"KKSOFT.IAP.FAIL"
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"KKSOFT.IAP.InvalidSKU"
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"KKSOFT.IAP.UserCancel"
                                                  object:nil];
}

@end

void KKSOFT_Initialize(UIViewController *unityViewController, OnCallback onCallBack) {
    if (onCallBack != KKSOFT_CallbackForwarder) {
        g_callback = onCallBack;
    }

    if (g_kksoftInitialized) {
        NSLog(@"KKSOFT - Initialize skipped, already initialized");
        return;
    }

    NSLog(@"KKSOFT - Initialize");
    g_kksoftInitialized = YES;
    g_proxy = KKSOFTProxy.shared;
    [g_proxy Initialize:unityViewController:KKSOFT_CallbackForwarder];
}

void KKSOFT_Auth() {
    NSLog(@"KKSOFT - Auth");
    [g_proxy Auth];
}

void KKSOFT_TokenExpiration() {
    NSLog(@"KKSOFT - Token Expiration");
    [g_proxy showTokenExpiration];
}

void KKSOFT_ServerMaintainance() {
    NSLog(@"KKSOFT - Server Maintainance");
    [g_proxy showServerMaintaince];
}

//void KKSOFT_RefreshedToken() {
//    NSLog(@"KKSOFT - Server Maintainance");
//    [g_proxy onRefreshedToken];
//}

void startSDK(id<AuthResultDelegate> delegate) {
    NSLog(@"✅ Showing SwiftUI SDK demo view from Unity");

    AuthManagerObjCBridge *bridge = GlobalAuthManagerBridge();

    [bridge setDelegate:delegate];

    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];

    [bridge initSDKWithPackageName:bundleId
                        appVersion:appVersion
                        serverId:@"IOS1"
                        completion:^(NSDictionary *session, NSString *popup, NSError *error) {
        if (session) {
            // Optionally use the session dictionary for pre-filling info, etc.
            NSLog(@"SDK initialized, session = %@", session);
            [[KeychainManagerObjCBridge shared] saveAuthSessionDict:session];
            NSString *accessToken = session[@"accessToken"];
            UIViewController *unityVC = _UnityAppController.rootViewController;
            [unityVC dismissViewControllerAnimated:YES completion:^{
                NSBundle *unityFrameworkBundle = [NSBundle bundleForClass:NSClassFromString(@"MenuDialogViewController")];

                MenuDialogViewController *dialog = [[MenuDialogViewController alloc] initWithNibName:@"MenuDialogViewController" bundle:unityFrameworkBundle];
                [dialog updateToken:accessToken];
                dialog.modalPresentationStyle = UIModalPresentationOverCurrentContext;
                [unityVC presentViewController:dialog animated:YES completion:nil];
            }];
            return;
        } else if ([popup isEqualToString:@"forceUpdate"]) {
            // Show force update UI, do not present SDK view
            NSLog(@"Force update required!");
            UIViewController *unityVC = _UnityAppController.rootViewController;
            NSString *appStoreId = @"YOUR_APP_STORE_ID"; // TODO: Replace with your actual App Store ID
            [bridge showForceUpdateViewWithAppStoreId:appStoreId from:unityVC];
            return;
        }

        NSLog(@"Show welcome screen");
        // Now present the SwiftUI SDK view in cases of error & no session
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *controller = [bridge showLoginView];

            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:controller];
            nav.modalPresentationStyle = UIModalPresentationOverFullScreen;

            UIViewController *unityVC = GetAppController().rootViewController;//  _UnityAppController.rootViewController;
            [unityVC presentViewController:nav animated:YES completion:nil];
        });
    }];
}

