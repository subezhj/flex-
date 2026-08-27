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
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.isKeyWindow) return window;
            }
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return UIApplication.sharedApplication.keyWindow;
#pragma clang diagnostic pop
}

static UIViewController *FPTopViewController(UIViewController *root) {
    UIViewController *top = root;
    for (NSUInteger i = 0; top.presentedViewController && i < 20; i++) {
        top = top.presentedViewController;
    }
    return top;
}

static void FPPresentFromKeyWindow(UIViewController *vc) {
    UIViewController *presenter = FPKeyWindow().rootViewController;
    if (!presenter) return;
    if ([presenter isKindOfClass:UINavigationController.class]) {
        presenter = ((UINavigationController *)presenter).topViewController ?: presenter;
    }
    presenter = FPTopViewController(presenter);
    vc.popoverPresentationController.sourceView = presenter.view;
    vc.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1);
    [presenter presentViewController:vc animated:YES completion:nil];
}

#pragma mark - 导出

// 主线程采集 + 后台打包,完成后弹分享。
static void FPExportSnapshot(void) {
    if (gFPExporting) return;
    gFPExporting = YES;

    NSString *dir = [FPLayoutSnapshot defaultCaptureDirectory];
    NSArray<NSString *> *files = [FPLayoutSnapshot captureIntoDirectory:dir];
    if (files.count == 0) {
        gFPExporting = NO;
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSString *zipPath = [dir stringByAppendingPathComponent:@"flexprobe-snapshot.zip"];
        NSError *zipError = nil;
        BOOL ok = [FPZipWriter createZipAtPath:zipPath rootDir:dir files:files
                                      progress:nil error:&zipError];
        dispatch_async(dispatch_get_main_queue(), ^{
            gFPExporting = NO;
            if (!ok) {
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
                if (!completed) return;
                // 分享完成后清理采集目录,只留 zip,避免 tmp 堆积。
                [[NSFileManager defaultManager] removeItemAtPath:dir error:nil];
            };
            FPPresentFromKeyWindow(share);
        });
    });
}

// 快速连拍:转场动画中间态肉眼盯不住,固定间隔采 3 份。
static void FPExportBurst(void) {
    if (gFPExporting) return;
    gFPExporting = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSUInteger i = 0; i < 3; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((double)i * 1.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                NSString *dir = [FPLayoutSnapshot defaultCaptureDirectory];
                NSArray<NSString *> *files = [FPLayoutSnapshot captureIntoDirectory:dir];
                if (files.count == 0) return;
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                    NSString *zipPath = [dir stringByAppendingPathComponent:@"flexprobe-snapshot.zip"];
                    [FPZipWriter createZipAtPath:zipPath rootDir:dir files:files progress:nil error:nil];
                });
            });
        }
        // 3 次连拍结束(约 4.5s 后)统一提示收尾。
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            gFPExporting = NO;
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"FlexProbe"
                                 message:[NSString stringWithFormat:@"连拍完成,3 份快照已写入:\n%@", [FPLayoutSnapshot defaultCaptureDirectory].stringByDeletingLastPathComponent]
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
