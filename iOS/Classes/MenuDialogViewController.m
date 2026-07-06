//
//  MenuDialogViewController.m
//  Unity-iPhone
//
//  Created by Admin on 8/5/25.
//
#import <UnityFramework/UnityAppController.h>
#import "MenuDialogViewController.h"
#import "AuthManagerBridgeGlobal.h"
#import <UnityFramework/UnityFramework-Swift.h>

@interface MenuDialogViewController ()
@property (weak, nonatomic) IBOutlet UILabel *tokenLabel;
@property (weak, nonatomic) IBOutlet UILabel *errorLabel;

@end

@implementation MenuDialogViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.3]];
    [self updateUI];
}

-(void)updateToken:(NSString *)token {
    _token = token;
}
-(void)updateError:(NSString *)error {
    _error = error;
}

-(void)updateUI {
    NSLog(@"%@", _token);
    [_tokenLabel setText:_token];
    [_errorLabel setText:_error];
}

// Helper method
- (void)presentLoginView {
    UIViewController *loginVC = [GlobalAuthManagerBridge() showLoginView];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:loginVC];
    nav.modalPresentationStyle = UIModalPresentationOverFullScreen;
    UIViewController *unityVC = UnityGetGLViewController();
    [unityVC presentViewController:nav animated:YES completion:nil];
}

- (void)presentMenuDialogOnUnityVC {
    UIViewController *unityVC = UnityGetGLViewController();
    NSBundle *unityFrameworkBundle = [NSBundle bundleForClass:NSClassFromString(@"MenuDialogViewController")];
    MenuDialogViewController *dialog = [[MenuDialogViewController alloc] initWithNibName:@"MenuDialogViewController" bundle:unityFrameworkBundle];
    
    NSDictionary *session = [KeychainManagerObjCBridge.shared loadAuthSessionDict];
    if (session) {
        NSLog(@"Loaded session: %@", session);
        NSString *accessToken = session[@"accessToken"];
        [dialog updateToken:accessToken];
        dialog.modalPresentationStyle = UIModalPresentationOverCurrentContext;
        [unityVC presentViewController:dialog animated:YES completion:nil];
    } else {
        NSLog(@"No session found in Keychain");
    }
}

- (IBAction)onLogout:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        UIViewController *logoutVC = [GlobalAuthManagerBridge() showLogoutWithCompletion:^(NSDictionary *result, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ((result == nil && error == nil) || error) {
                    UIViewController *unityVC = _UnityAppController.rootViewController;
                    [unityVC dismissViewControllerAnimated:YES completion:^{
                        [self presentMenuDialogOnUnityVC];
                    }];
                } else {
                    self->_token = @"";
                    self->_error = @"Logged out successfully";
                    [KeychainManagerObjCBridge.shared clearAuthSession];
                    // Dismiss the dialog and present login view
                    [self dismissViewControllerAnimated:YES completion:^{
                        [self presentLoginView];
                    }];
                }
            });
        }];
        
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:logoutVC];
        nav.modalPresentationStyle = UIModalPresentationOverFullScreen;
        UIViewController *unityVC = UnityGetGLViewController();
        [unityVC presentViewController:nav animated:YES completion:nil];
    }];
}

- (IBAction)onChangeGameServer:(id)sender {
    // Dismiss this dialog (MenuDialogViewController)
    [self dismissViewControllerAnimated:YES completion:^{
        UIViewController *gameServerVC = [GlobalAuthManagerBridge() showGameServerViewWithCompletion:^(NSDictionary *result, NSError *error) {
            // After game server selection is done, show MenuDialogViewController again
            dispatch_async(dispatch_get_main_queue(), ^{
                UIViewController *unityVC = _UnityAppController.rootViewController;
                [unityVC dismissViewControllerAnimated:YES completion:^{
                    [self presentMenuDialogOnUnityVC];
                }];
            });
        }];
        
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:gameServerVC];
        nav.modalPresentationStyle = UIModalPresentationOverFullScreen;
        
        UIViewController *unityVC = UnityGetGLViewController();
        [unityVC presentViewController:nav animated:YES completion:nil];
    }];
}

- (IBAction)onGetLatestSession:(id)sender {
    [GlobalAuthManagerBridge() getLatestSessionWithCompletion:^(NSDictionary *result, NSError *error) {
        if (error) {
            self->_error = error.localizedDescription;
            self->_token = @"";
            [self updateUI];
        } else {
            self->_token = result[@"accessToken"];
            self->_error = @"Get Latest Session successfully";
            [self updateUI];
        }
    }];
}

- (IBAction)onRefreshToken:(id)sender {
    [GlobalAuthManagerBridge() refreshTokenWithCompletion:^(NSDictionary *result, NSError *error) {
        if (error) {
            self->_error = error.localizedDescription;
            self->_token = @"";
            [self updateUI];
        } else {
            self->_token = result[@"accessToken"];
            self->_error = @"Refresh Account successfully";
            [self updateUI];
        }
    }];
}

- (IBAction)onDeleteAccount:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        UIViewController *vc = [GlobalAuthManagerBridge() showDeactivateAccountWithCompletion:^(NSDictionary *result, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ((result == nil && error == nil) || error) {
                    UIViewController *unityVC = _UnityAppController.rootViewController;
                    [unityVC dismissViewControllerAnimated:YES completion:^{
                        [self presentMenuDialogOnUnityVC];
                    }];
                } else {
                    self->_token = @"";
                    self->_error = @"Delete account successfully";
                    [KeychainManagerObjCBridge.shared clearAuthSession];
                    // Dismiss the dialog and present login view
                    [self dismissViewControllerAnimated:YES completion:^{
                        [self presentLoginView];
                    }];
                }
            });
        }];
        
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.modalPresentationStyle = UIModalPresentationOverFullScreen;
        UIViewController *unityVC = UnityGetGLViewController();
        [unityVC presentViewController:nav animated:YES completion:nil];
    }];
}

@end
