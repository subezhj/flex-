//
//  FPEntry.m
//  FlexProbe
//
//  入口:三指双击唤起菜单(与 FLEX++ 自带的三指长按并存,互不冲突):
//    · 导出布局快照 → 生成 zip → 系统分享面板(存到"文件"/AirDrop/微信 发给电脑)
//    · 打开 FLEX++ 调试面板
//    · 快速连拍:间隔 1.5s 连续导出 3 份快照(适合抓转场/动画中间态)
//
//  纯 UIKit 公开 API,无 Logos 依赖,可直接并入任何 Theos 工程。
//

#import "FPLayoutSnapshot.h"
#import "FPZipWriter.h"
#import "FLEXManager.h"
#import "FLEXWindow.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static UITapGestureRecognizer *gFPGesture = nil;
static __weak UIWindow *gFPGestureWindow = nil;
static BOOL gFPExporting = NO;

// 前向声明：relay 回调在菜单函数定义之前被引用（见 probeTriggered:）。
static void FPShowMenu(void);

// 手势 target 必须被强持有:UIKit 对 target 是 unsafe_unretained,
// 临时对象(如 NSBlockOperation)会被立即释放导致悬垂崩溃。
@interface FPGestureRelay : NSObject
@end

@implementation FPGestureRelay
- (void)probeTriggered:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) FPShowMenu();
}
@end

static FPGestureRelay *gFPRelay = nil;

#pragma mark - 工具

static UIWindow *FPKeyWindow(void) {
    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class] ||
                scene.activationState != UISceneActivationStateForegroundActive) continue;
            [windows addObjectsFromArray:((UIWindowScene *)scene).windows];
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (!windows.count) [windows addObjectsFromArray:UIApplication.sharedApplication.windows];
#pragma clang diagnostic pop
    UIWindow *fallback = nil;
    for (UIWindow *window in windows) {
        if ([window isKindOfClass:FLEXWindow.class] || window.hidden || window.alpha < 0.01 ||
            window.windowLevel != UIWindowLevelNormal || !window.rootViewController) continue;
        if (window.isKeyWindow) return window;
        if (!fallback) fallback = window;
    }
    return fallback;
}

static UIViewController *FPTopViewController(UIViewController *root) {
    UIViewController *top = root;
    for (NSUInteger i = 0; top.presentedViewController && i < 20; i++) {
        top = top.presentedViewController;
    }
    return top;
}

static BOOL FPPresentFromKeyWindow(UIViewController *vc) {
    UIViewController *presenter = FPKeyWindow().rootViewController;
    if (!presenter) return NO;
    if ([presenter isKindOfClass:UINavigationController.class]) {
        presenter = ((UINavigationController *)presenter).topViewController ?: presenter;
    }
    presenter = FPTopViewController(presenter);
    vc.popoverPresentationController.sourceView = presenter.view;
    vc.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1);
    if (presenter.isBeingDismissed || presenter.isBeingPresented) return NO;
    NSLog(@"[FlexProbe] presenting %@ from %@", vc.class, presenter.class);
    [presenter presentViewController:vc animated:YES completion:nil];
    return YES;
}

#pragma mark - 导出

// 主线程采集 + 后台打包,完成后弹分享。
static void FPExportSnapshot(void) {
    if (gFPExporting) return;
    gFPExporting = YES;

    NSString *dir = [FPLayoutSnapshot defaultCaptureDirectory];
    [FPLayoutSnapshot captureIntoDirectory:dir completion:^(NSArray<NSString *> *files, NSError *captureError) {
        if (!files.count) {
            dispatch_async(dispatch_get_main_queue(), ^{
                gFPExporting = NO;
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FlexProbe"
                    message:captureError.localizedDescription ?: @"采集失败" preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];
                FPPresentFromKeyWindow(alert);
            });
            return;
        }
        NSString *zipPath = [dir stringByAppendingPathComponent:@"flexprobe-snapshot.zip"];
        NSError *zipError = nil;
        BOOL ok = [FPZipWriter createZipAtPath:zipPath rootDir:dir files:files
                                      progress:nil error:&zipError];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!ok) {
                gFPExporting = NO;
                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:@"FlexProbe"
                                     message:[NSString stringWithFormat:@"打包失败: %@", zipError.localizedDescription]
                              preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];
                FPPresentFromKeyWindow(alert);
                return;
            }

            NSURL *url = [NSURL fileURLWithPath:zipPath];
            UIActivityViewController *share =
                [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
            share.completionWithItemsHandler = ^(__unused NSString *type, BOOL completed,
                                                 __unused NSArray *items, __unused NSError *error) {
                NSLog(@"[FlexProbe] share finished: type=%@ completed=%d error=%@ zip=%@", type, completed, error, zipPath);
                dispatch_async(dispatch_get_main_queue(), ^{ gFPExporting = NO; });
                // Keep the ZIP available to file providers; remove only source files off main.
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                    for (NSString *file in files) {
                        [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
                    }
                    NSLog(@"[FlexProbe] source cleanup finished; retained ZIP: %@", zipPath);
                });
            };
            if (!FPPresentFromKeyWindow(share)) {
                gFPExporting = NO;
                NSLog(@"[FlexProbe] share presentation unavailable; ZIP retained: %@", zipPath);
            }
        });
    }];
}

// 快速连拍:转场动画中间态肉眼盯不住,固定间隔采 3 份。
static void FPExportBurst(void) {
    if (gFPExporting) return;
    gFPExporting = YES;
    dispatch_group_t group = dispatch_group_create();
    __block NSUInteger succeeded = 0;
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSUInteger i = 0; i < 3; i++) {
            dispatch_group_enter(group);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((double)i * 1.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                NSString *dir = [FPLayoutSnapshot defaultCaptureDirectory];
                [FPLayoutSnapshot captureIntoDirectory:dir completion:^(NSArray<NSString *> *files, NSError *error) {
                    if (!files.count) { NSLog(@"[FlexProbe] burst capture failed: %@", error); dispatch_group_leave(group); return; }
                    NSString *zipPath = [dir stringByAppendingPathComponent:@"flexprobe-snapshot.zip"];
                    BOOL ok = [FPZipWriter createZipAtPath:zipPath rootDir:dir files:files progress:nil error:nil];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (ok) succeeded++;
                        dispatch_group_leave(group);
                    });
                }];
            });
        }
        // Wait for all captures and background writes before reporting completion.
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            gFPExporting = NO;
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"FlexProbe"
                                 message:[NSString stringWithFormat:@"连拍完成,%lu/3 份快照已写入:\n%@", (unsigned long)succeeded, [FPLayoutSnapshot defaultCaptureDirectory].stringByDeletingLastPathComponent]
                          preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];
            FPPresentFromKeyWindow(alert);
        });
    });
}

#pragma mark - 菜单

static void FPShowMenu(void) {
    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:@"FlexProbe 布局抓取"
                         message:@"导出当前全部窗口的视图树 / 控制器树快照"
                  preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"📸 导出布局快照(分享)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *a) { FPExportSnapshot(); }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"🎞 快速连拍 ×3(写 tmp,1.5s 间隔)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *a) { FPExportBurst(); }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"🚀 打开 FLEX++ 调试面板"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *a) {
        [[FLEXManager sharedManager] showExplorer];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    FPPresentFromKeyWindow(sheet);
}

#pragma mark - 手势安装

static void FPInstallGesture(void) {
    UIWindow *window = FPKeyWindow();
    if (!window || window == gFPGestureWindow) return;

    if (gFPGesture && gFPGesture.view) {
        [gFPGesture.view removeGestureRecognizer:gFPGesture];
    }
    if (!gFPRelay) gFPRelay = [[FPGestureRelay alloc] init];
    gFPGesture = [[UITapGestureRecognizer alloc] initWithTarget:gFPRelay
                                                        action:@selector(probeTriggered:)];
    gFPGesture.numberOfTouchesRequired = 3;
    gFPGesture.numberOfTapsRequired = 2;
    gFPGesture.cancelsTouchesInView = NO;
    [window addGestureRecognizer:gFPGesture];
    gFPGestureWindow = window;
}

#pragma mark - 启动

__attribute__((constructor))
static void FlexProbeEntryInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        FPInstallGesture();
    });
    // keyWindow 变化(切场景/新窗口)时重挂手势。
    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIWindowDidBecomeKeyNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(__unused NSNotification *note) {
        FPInstallGesture();
    }];
}
