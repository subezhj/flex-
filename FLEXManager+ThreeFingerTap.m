#import "FLEXManager+ThreeFingerTap.h"
#import "FLEXManager.h"
#import "UIGestureRecognizer+Blocks.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *const kFLEXThreeFingerTapEnabledUserDefaultsKey = @"FLEXThreeFingerTapEnabledKey";
static UILongPressGestureRecognizer *flex_threeFingerLongPressGesture = nil;

@implementation FLEXManager (ThreeFingerTap)

+ (BOOL)isThreeFingerTapEnabled {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:kFLEXThreeFingerTapEnabledUserDefaultsKey];
    if (!value) {
        return YES; // 默认开启
    }
    return [value boolValue];
}

+ (void)setThreeFingerTapEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kFLEXThreeFingerTapEnabledUserDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if (enabled) {
        [self flex_setupGesture];
    } else {
        if (flex_threeFingerLongPressGesture && flex_threeFingerLongPressGesture.view) {
            [flex_threeFingerLongPressGesture.view removeGestureRecognizer:flex_threeFingerLongPressGesture];
            flex_threeFingerLongPressGesture = nil;
        }
    }
}

+ (void)load {
    if ([NSThread isMainThread]) {
        [self flex_setupGesture];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self flex_setupGesture];
        });
    }
}

+ (void)flex_setupGesture {
    if (![self isThreeFingerTapEnabled]) {
        if (flex_threeFingerLongPressGesture && flex_threeFingerLongPressGesture.view) {
            [flex_threeFingerLongPressGesture.view removeGestureRecognizer:flex_threeFingerLongPressGesture];
            flex_threeFingerLongPressGesture = nil;
        }
        return;
    }

    UIWindow *targetWindow = [self flex_findTargetWindow];

    if (!targetWindow) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self flex_setupGesture];
        });
        return;
    }

    for (UIGestureRecognizer *existingGesture in targetWindow.gestureRecognizers) {
        if (existingGesture == flex_threeFingerLongPressGesture) {
            if (existingGesture.view == targetWindow) {
                 return;
            } else {
                [existingGesture.view removeGestureRecognizer:existingGesture];
                flex_threeFingerLongPressGesture = nil;
            }
        }
    }
    
    if (flex_threeFingerLongPressGesture && flex_threeFingerLongPressGesture.view != targetWindow) {
        [flex_threeFingerLongPressGesture.view removeGestureRecognizer:flex_threeFingerLongPressGesture];
        flex_threeFingerLongPressGesture = nil;
    }

    if (!flex_threeFingerLongPressGesture) {
        flex_threeFingerLongPressGesture = [UILongPressGestureRecognizer flex_action:^(UIGestureRecognizer *gesture) {
            if (gesture.state == UIGestureRecognizerStateBegan) {
                if (![FLEXManager isThreeFingerTapEnabled]) return;
                [FLEXManager presentThreeFingerConflictAlertInWindow:targetWindow];
            }
        }];
        
        flex_threeFingerLongPressGesture.numberOfTouchesRequired = 3;
    }

    if (flex_threeFingerLongPressGesture.view && flex_threeFingerLongPressGesture.view != targetWindow) {
        [flex_threeFingerLongPressGesture.view removeGestureRecognizer:flex_threeFingerLongPressGesture];
    }
    
    if (flex_threeFingerLongPressGesture.view != targetWindow) {
        [targetWindow addGestureRecognizer:flex_threeFingerLongPressGesture];
    }
}

+ (void)presentThreeFingerConflictAlertInWindow:(UIWindow *)targetWindow {
    UIViewController *topVC = targetWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    if ([topVC isKindOfClass:[UINavigationController class]]) {
        topVC = [(UINavigationController *)topVC topViewController];
    }
    
    if (!topVC) return;
    
    // 监测窗口上是否存在其他 3 指手势识别器
    BOOL hasOtherThreeFingerGestures = NO;
    for (UIGestureRecognizer *g in targetWindow.gestureRecognizers) {
        if (g != flex_threeFingerLongPressGesture) {
            if ([g isKindOfClass:[UITapGestureRecognizer class]] && [(UITapGestureRecognizer *)g numberOfTouchesRequired] == 3) {
                hasOtherThreeFingerGestures = YES;
                break;
            }
            if ([g isKindOfClass:[UILongPressGestureRecognizer class]] && [(UILongPressGestureRecognizer *)g numberOfTouchesRequired] == 3) {
                hasOtherThreeFingerGestures = YES;
                break;
            }
        }
    }
    
    NSString *message = hasOtherThreeFingerGestures
        ? @"检测到当前界面存在其他插件的三指手势，请选择您要调出的调试工具："
        : @"检测到三指轻敲手势，请选择需要执行的操作：";
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"💡 三指轻敲手势调出"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"打开 FLEX++ 调试面板"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        if ([FLEXManager sharedManager]) {
            [[FLEXManager sharedManager] toggleExplorer];
        }
    }]];
    
    if (hasOtherThreeFingerGestures) {
        [alert addAction:[UIAlertAction actionWithTitle:@"打开其他调试工具"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
            // 允许手势向下传递或让其他插件接收
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭三指唤醒功能"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction * _Nonnull action) {
        [FLEXManager setThreeFingerTapEnabled:NO];
        UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"已关闭三指唤醒"
                                                                         message:@"三指唤醒已停用。你随时可在 FLEX++ 设置或插件菜单中重新开启。"
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil]];
        [topVC presentViewController:confirm animated:YES completion:nil];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [topVC presentViewController:alert animated:YES completion:nil];
}

+ (UIWindow *)flex_findTargetWindow {
    UIWindow *applicationWindow = nil;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    // 优先选择一个非FLEXWindow的key window
                    if (window.isKeyWindow && ![NSStringFromClass(window.class) isEqualToString:@"FLEXWindow"]) {
                        applicationWindow = window;
                        break;
                    }
                }
                if (applicationWindow) break;

                // 备选：活动场景中的任何key window
                if (!applicationWindow) {
                    for (UIWindow *window in windowScene.windows) {
                        if (window.isKeyWindow) {
                            applicationWindow = window;
                            break;
                        }
                    }
                }
                if (applicationWindow) break;
                
                // 备选：活动场景中的第一个非FLEXWindow
                 if (!applicationWindow) {
                    for (UIWindow *window in windowScene.windows) {
                        if (![NSStringFromClass(window.class) isEqualToString:@"FLEXWindow"]) {
                            applicationWindow = window;
                            break;
                        }
                    }
                }
                if (applicationWindow) break;
            }
        }
    }

    // iOS < 13 或通过场景未找到合适窗口时的备选方案
    if (!applicationWindow) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSArray<UIWindow *> *windows = [UIApplication sharedApplication].windows;
        for (UIWindow *window in windows) {
            if (window.isKeyWindow && ![NSStringFromClass(window.class) isEqualToString:@"FLEXWindow"]) {
                applicationWindow = window;
                break;
            }
        }
        // 如果上面的尝试失败了，就获取当前的keyWindow（有可能是FLEXWindow）
        if (!applicationWindow) {
            applicationWindow = [UIApplication sharedApplication].keyWindow;
        }
        
        // 如果获取到的keyWindow是FLEXWindow，尝试寻找其他非FLEXWindow且可见的窗口
        if (applicationWindow && [NSStringFromClass(applicationWindow.class) isEqualToString:@"FLEXWindow"]) {
            UIWindow* fallbackWindow = nil;
            for (UIWindow *window in windows) {
                if (![NSStringFromClass(window.class) isEqualToString:@"FLEXWindow"] && !window.isHidden) {
                    fallbackWindow = window; // 找到一个可用的非FLEX窗口
                    if (window.isKeyWindow) { // 如果这个窗口恰好也是key window，优先使用
                        applicationWindow = window;
                        break;
                    }
                }
            }
            if (![NSStringFromClass(applicationWindow.class) isEqualToString:@"FLEXWindow"] || !fallbackWindow) {
                 // 如果applicationWindow仍然是FLEXWindow，或者没有找到fallbackWindow，则保持原样
            } else {
                applicationWindow = fallbackWindow; // 使用找到的非FLEX窗口
            }
        }
        #pragma clang diagnostic pop
    }
    
    return applicationWindow;
}

@end