#import "FLEXManager+ThreeFingerTap.h"
#import "FLEXManager.h"
#import "UIGestureRecognizer+Blocks.h"
#import "FLEXCompatibility.h"
#import "FLEXColor.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *const kFLEXThreeFingerTapEnabledUserDefaultsKey = @"FLEXThreeFingerTapEnabledKey";
static UILongPressGestureRecognizer *flex_threeFingerLongPressGesture = nil;

@interface FLEXThreeFingerGlassMenuViewController : UIViewController
@property (nonatomic, assign) BOOL hasOtherThreeFingerGestures;
@property (nonatomic, copy) void (^onOpenFLEX)(void);
@property (nonatomic, copy) void (^onOpenOther)(void);
@property (nonatomic, copy) void (^onToggleGesture)(void);
@end

@implementation FLEXThreeFingerGlassMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    
    UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissSelf)];
    [self.view addGestureRecognizer:bgTap];
    
    [self setupGlassCard];
}

- (void)setupGlassCard {
    UIView *cardContainer = [UIView new];
    cardContainer.translatesAutoresizingMaskIntoConstraints = NO;
    cardContainer.layer.cornerRadius = 24.0;
    cardContainer.clipsToBounds = YES;
    cardContainer.layer.borderWidth = 0.5;
    cardContainer.layer.borderColor = [FLEXColor glassBorderColor].CGColor;
    
    cardContainer.layer.shadowColor = UIColor.blackColor.CGColor;
    cardContainer.layer.shadowOpacity = 0.25;
    cardContainer.layer.shadowRadius = 16.0;
    cardContainer.layer.shadowOffset = CGSizeMake(0, 8);
    
    UIVisualEffectView *blurView = nil;
#if FLEX_AT_LEAST_IOS13_SDK
    if (@available(iOS 13.0, *)) {
        blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:FLEXBlurEffectStyleSystemThinMaterial]];
    }
#endif
    if (!blurView) {
        blurView = [UIVisualEffectView new];
        blurView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:0.95];
    }
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [cardContainer addSubview:blurView];
    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:cardContainer.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:cardContainer.bottomAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:cardContainer.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:cardContainer.trailingAnchor]
    ]];
    
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12.0;
    stack.alignment = UIStackViewAlignmentFill;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [cardContainer addSubview:stack];
    
    UILabel *titleLabel = [UILabel new];
    titleLabel.text = @"✨ FLEX++ 液态调试";
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    titleLabel.textColor = FLEXLabelColor;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [stack addArrangedSubview:titleLabel];
    
    UILabel *subLabel = [UILabel new];
    subLabel.text = self.hasOtherThreeFingerGestures
        ? @"检测到界面存在其他插件的三指手势，请选择："
        : @"检测到三指手势，请选择要调出的操作：";
    subLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    subLabel.textColor = FLEXSecondaryLabelColor;
    subLabel.textAlignment = NSTextAlignmentCenter;
    subLabel.numberOfLines = 0;
    [stack addArrangedSubview:subLabel];
    
    UIView *space = [UIView new];
    [space.heightAnchor constraintEqualToConstant:4].active = YES;
    [stack addArrangedSubview:space];
    
    UIButton *btnFLEX = [self createGlassButtonWithTitle:@"🚀 打开 FLEX++ 调试面板" isDestructive:NO action:@selector(btnFLEXTapped)];
    [stack addArrangedSubview:btnFLEX];
    
    if (self.hasOtherThreeFingerGestures) {
        UIButton *btnOther = [self createGlassButtonWithTitle:@"⚡ 打开其他调试工具" isDestructive:NO action:@selector(btnOtherTapped)];
        [stack addArrangedSubview:btnOther];
    }
    
    BOOL isEnabled = [FLEXManager isThreeFingerTapEnabled];
    NSString *toggleTitle = isEnabled ? @"⚙️ 三指唤醒: 已开启 (点击关闭)" : @"⚙️ 三指唤醒: 已关闭 (点击开启)";
    UIButton *btnToggle = [self createGlassButtonWithTitle:toggleTitle isDestructive:isEnabled action:@selector(btnToggleTapped)];
    [stack addArrangedSubview:btnToggle];
    
    UIButton *btnCancel = [self createGlassButtonWithTitle:@"✕ 取消" isDestructive:NO action:@selector(dismissSelf)];
    [stack addArrangedSubview:btnCancel];
    
    [self.view addSubview:cardContainer];
    [NSLayoutConstraint activateConstraints:@[
        [cardContainer.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [cardContainer.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [cardContainer.widthAnchor constraintEqualToConstant:300.0],
        [stack.topAnchor constraintEqualToAnchor:cardContainer.topAnchor constant:20.0],
        [stack.bottomAnchor constraintEqualToAnchor:cardContainer.bottomAnchor constant:-20.0],
        [stack.leadingAnchor constraintEqualToAnchor:cardContainer.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:cardContainer.trailingAnchor constant:-16.0]
    ]];
    
    cardContainer.transform = CGAffineTransformMakeScale(0.85, 0.85);
    cardContainer.alpha = 0.0;
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:0 animations:^{
        cardContainer.transform = CGAffineTransformIdentity;
        cardContainer.alpha = 1.0;
    } completion:nil];
}

- (UIButton *)createGlassButtonWithTitle:(NSString *)title isDestructive:(BOOL)isDestructive action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [button setTitleColor:(isDestructive ? FLEXSystemRedColor : FLEXLabelColor) forState:UIControlStateNormal];
    button.backgroundColor = [FLEXColor glassCardBackgroundColor];
    button.layer.cornerRadius = 14.0;
    button.layer.borderWidth = 0.5;
    button.layer.borderColor = [FLEXColor glassBorderColor].CGColor;
    button.clipsToBounds = YES;
    [button.heightAnchor constraintEqualToConstant:44.0].active = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)btnFLEXTapped {
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.onOpenFLEX) self.onOpenFLEX();
    }];
}

- (void)btnOtherTapped {
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.onOpenOther) self.onOpenOther();
    }];
}

- (void)btnToggleTapped {
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.onToggleGesture) self.onToggleGesture();
    }];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

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

+ (void)setIsThreeFingerTapEnabled:(BOOL)enabled {
    [self setThreeFingerTapEnabled:enabled];
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
    
    FLEXThreeFingerGlassMenuViewController *menuVC = [FLEXThreeFingerGlassMenuViewController new];
    menuVC.hasOtherThreeFingerGestures = hasOtherThreeFingerGestures;
    menuVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
    menuVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    menuVC.onOpenFLEX = ^{
        if ([FLEXManager sharedManager]) {
            [[FLEXManager sharedManager] toggleExplorer];
        }
    };
    menuVC.onOpenOther = ^{
        // 允许传递给其他插件
    };
    menuVC.onToggleGesture = ^{
        BOOL current = [FLEXManager isThreeFingerTapEnabled];
        [FLEXManager setThreeFingerTapEnabled:!current];
    };
    
    [topVC presentViewController:menuVC animated:YES completion:nil];
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