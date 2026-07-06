//
//  MenuDialogViewController.h
//  Unity-iPhone
//
//  Created by Admin on 8/5/25.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MenuDialogViewController : UIViewController
@property (nonatomic, readonly) NSString *token;
@property (nonatomic, readonly) NSString *error;

-(void)updateToken:(NSString *)token;
-(void)updateError:(NSString *)error;

@end

NS_ASSUME_NONNULL_END
