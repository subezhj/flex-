#import "FLEXManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLEXManager (ThreeFingerTap)

/// 开关三指轻敲调出 FLEX (默认开启，自动通过 NSUserDefaults 持久化保存)
@property (class, nonatomic, assign, getter=isThreeFingerTapEnabled, setter=setThreeFingerTapEnabled:) BOOL threeFingerTapEnabled;

+ (BOOL)isThreeFingerTapEnabled;
+ (void)setThreeFingerTapEnabled:(BOOL)enabled;
+ (void)setIsThreeFingerTapEnabled:(BOOL)enabled;

/// 弹出三指轻敲冲突拦截与选择对话框
+ (void)presentThreeFingerConflictAlertInWindow:(UIWindow *)targetWindow;

@end

NS_ASSUME_NONNULL_END