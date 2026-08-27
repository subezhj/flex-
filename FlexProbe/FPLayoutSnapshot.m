//
//  FPLayoutSnapshot.m
//  FlexProbe
//
//  采集内容与格式约定(与 tools/analyze_layout_zip.py 配套):
//
//    meta.txt          采集环境:时间 / bundle / 系统 / 设备 / 屏幕 / 方向 / 外观
//    layout-tree.txt   人读视图树:每行一个视图,缩进表达层级,含关键布局属性
//    vc-tree.txt       人读控制器树:child / presented / nav / tab 全展开
//    layout.json       机读版本:与 txt 同源的结构化数据,字段见 FPViewNodeKey
//
//  只读 UIKit 公开属性,不 KVC、不碰私有 ivar,保证在任意目标 App 里采集零副作用。
//

#import "FPLayoutSnapshot.h"
#import <UIKit/UIKit.h>

static NSString *const kFPMetaFile = @"meta.txt";
static NSString *const kFTreeFile = @"layout-tree.txt";
static NSString *const kFVCTreeFile = @"vc-tree.txt";
static NSString *const kFJSONFile = @"layout.json";

static const NSUInteger kFPMaxNodes = 30000;
static const NSUInteger kFPMaxDepth = 64;

#pragma mark - 小工具

static NSString *FPPointString(CGPoint p) {
    return [NSString stringWithFormat:@"{%.1f,%.1f}", p.x, p.y];
}

static NSString *FPSizeString(CGSize s) {
    return [NSString stringWithFormat:@"{%.1f,%.1f}", s.width, s.height];
}

static NSString *FPRectString(CGRect r) {
    return [NSString stringWithFormat:@"{{%.1f,%.1f},{%.1f,%.1f}}",
            r.origin.x, r.origin.y, r.size.width, r.size.height];
}

static NSDictionary *FPRectDict(CGRect r) {
    return @{ @"x": @((double)(int)(r.origin.x * 100) / 100.0),
              @"y": @((double)(int)(r.origin.y * 100) / 100.0),
              @"w": @((double)(int)(r.size.width * 100) / 100.0),
              @"h": @((double)(int)(r.size.height * 100) / 100.0) };
}

// 背景色转 #RRGGBBAA(带 alpha),非 RGB 色系(如 pattern)返回 nil。
static NSString *FPColorHex(UIColor *color) {
    if (!color) return nil;
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) {
        CGFloat w = 0;
        if (![color getWhite:&w alpha:&a]) return nil;
        r = g = b = w;
    }
    return [NSString stringWithFormat:@"#%02X%02X%02X%02X",
            (unsigned)(r * 255) & 0xFF, (unsigned)(g * 255) & 0xFF,
            (unsigned)(b * 255) & 0xFF, (unsigned)(a * 255) & 0xFF];
}

static NSString *FPResponderViewController(UIResponder *responder) {
    for (NSUInteger i = 0; responder && i < 40; i++) {
        if ([responder isKindOfClass:UIViewController.class]) {
            return NSStringFromClass(responder.class);
        }
        responder = responder.nextResponder;
    }
    return nil;
}

// 取主 window(iOS 13+ 场景 API 优先,回落 keyWindow)。
static UIWindow *FPKeyWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) return window;
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return UIApplication.sharedApplication.keyWindow;
#pragma clang diagnostic pop
}

static NSString *FPDocumentDirectory(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return paths.firstObject ?: NSTemporaryDirectory();
}

#pragma mark - 视图节点采集

static NSUInteger FPViewActiveConstraints(UIView *view) {
    NSUInteger active = 0;
    for (NSLayoutConstraint *c in view.constraints) {
        if (c.active) active++;
    }
    return active;
}

// 递归:文本树一行 + JSON 节点。返回累计节点数。
static NSUInteger FPDumpView(UIView *view,
                             NSUInteger depth,
                             UIWindow *window,
                             NSMutableString *tree,
                             NSMutableArray<NSMutableDictionary *> *jsonChildren,
                             NSUInteger *ioTotal) {
    NSUInteger total = *ioTotal;
    if (depth > kFPMaxDepth || total >= kFPMaxNodes) return total;
    total++;
    *ioTotal = total;

    CGRect windowFrame = [view convertRect:view.bounds toView:window ?: view.window];
    NSString *className = NSStringFromClass(view.class);
    NSString *vcName = FPResponderViewController(view);
    NSString *bgHex = FPColorHex(view.backgroundColor);
    NSString *ptr = [NSString stringWithFormat:@"%p", view];

    [tree appendFormat:@"%@[%@:%@] f=%@ wf=%@ bounds=%@%@%@%@%@%@ cons=%lu/%lu intrinsic=%@%@\n",
        [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0],
        className, ptr,
        FPRectString(view.frame),
        FPRectString(windowFrame),
        FPSizeString(view.bounds.size),
        view.isHidden ? @" hidden" : @"",
        view.alpha < 0.99 ? [NSString stringWithFormat:@" a=%.2f", view.alpha] : @"",
        view.clipsToBounds ? @" clip" : @"",
        view.layer.cornerRadius > 0.5 ? [NSString stringWithFormat:@" corner=%.1f", view.layer.cornerRadius] : @"",
        bgHex ? [NSString stringWithFormat:@" bg=%@", bgHex] : @"",
        (unsigned long)FPViewActiveConstraints(view),
        (unsigned long)view.constraints.count,
        CGSizeEqualToSize(view.intrinsicContentSize, CGSizeZero)
            ? @"-" : FPSizeString(view.intrinsicContentSize),
        vcName ? [NSString stringWithFormat:@" vc=%@", vcName] : @""];

    NSMutableDictionary *node = [NSMutableDictionary dictionary];
    node[@"class"] = className;
    node[@"ptr"] = ptr;
    node[@"frame"] = FPRectDict(view.frame);
    node[@"windowFrame"] = FPRectDict(windowFrame);
    node[@"bounds"] = FPRectDict(view.bounds);
    node[@"hidden"] = @(view.isHidden);
    node[@"alpha"] = @((double)(int)(view.alpha * 100) / 100.0);
    node[@"opaque"] = @((view).opaque);
    node[@"clips"] = @(view.clipsToBounds);
    node[@"touch"] = @(view.userInteractionEnabled);
    node[@"autoresizing"] = @((unsigned long)view.autoresizingMask);
    node[@"constraintsActive"] = @((unsigned long)FPViewActiveConstraints(view));
    node[@"constraintsTotal"] = @((unsigned long)view.constraints.count);
    if (!CGSizeEqualToSize(view.intrinsicContentSize, CGSizeZero)) {
        node[@"intrinsic"] = FPRectDict((CGRect){ .size = view.intrinsicContentSize });
    }
    if (view.layer.cornerRadius > 0.5) {
        node[@"cornerRadius"] = @((double)(int)(view.layer.cornerRadius * 10) / 10.0);
    }
    if (bgHex) node[@"bg"] = bgHex;
    if (vcName) node[@"vc"] = vcName;

    NSMutableArray<NSMutableDictionary *> *children = [NSMutableArray array];
    for (UIView *sub in view.subviews) {
        total = FPDumpView(sub, depth + 1, window, tree, children, &total);
        if (total >= kFPMaxNodes) break;
    }
    if (children.count) node[@"subviews"] = children;
    [jsonChildren addObject:node];
    *ioTotal = total;
    return total;
}

#pragma mark - 控制器树采集

static void FPDumpViewController(UIViewController *vc,
                                 NSUInteger depth,
                                 NSMutableString *tree,
                                 NSMutableArray<NSMutableDictionary *> *jsonChildren) {
    if (!vc || depth > kFPMaxDepth) return;

    NSString *title = vc.title.length ? [NSString stringWithFormat:@" title=%@", vc.title] : @"";
    NSString *viewDesc = vc.isViewLoaded
        ? [NSString stringWithFormat:@" view=%@", FPSizeString(vc.view.frame.size)]
        : @" view=(未加载)";
    [tree appendFormat:@"%@- %@%@%@%@\n",
        [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0],
        NSStringFromClass(vc.class), title, viewDesc,
        vc.viewIfLoaded && vc.viewIfLoaded.isHidden ? @" (viewHidden)" : @""];

    NSMutableDictionary *node = [NSMutableDictionary dictionary];
    node[@"class"] = NSStringFromClass(vc.class);
    if (vc.title.length) node[@"title"] = vc.title;
    if (vc.isViewLoaded) node[@"viewFrame"] = FPRectDict(vc.view.frame);

    NSMutableArray<NSMutableDictionary *> *children = [NSMutableArray array];
    for (UIViewController *child in vc.childViewControllers) {
        FPDumpViewController(child, depth + 1, tree, children);
    }
    if (vc.presentedViewController) {
        NSMutableDictionary *presented = [NSMutableDictionary dictionary];
        presented[@"class"] = NSStringFromClass(vc.presentedViewController.class);
        presented[@"presented"] = @YES;
        [tree appendFormat:@"%@  ↳ presented: %@\n",
            [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0],
            presented[@"class"]];
        [children addObject:presented];
    }
    if (children.count) node[@"children"] = children;
    [jsonChildren addObject:node];
}

#pragma mark - meta

static NSDictionary *FPMetaDictionary(NSString *bundleID) {
    NSBundle *bundle = NSBundle.mainBundle;
    UIDevice *device = UIDevice.currentDevice;
    UIScreen *screen = UIScreen.mainScreen;
    UIWindow *key = FPKeyWindow();

    return @{
        @"capturedAt": [NSDateFormatter localizedStringFromDate:NSDate.date
                                                      dateStyle:NSDateFormatterMediumStyle
                                                      timeStyle:NSDateFormatterMediumStyle],
        @"bundleID": bundleID ?: @"",
        @"appVersion": [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"",
        @"appBuild": [bundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"",
        @"systemVersion": device.systemVersion ?: @"",
        @"deviceModel": [device model] ?: @"",
        @"screenBounds": FPRectDict(screen.bounds),
        @"screenScale": @(screen.scale),
        @"screenNativeScale": @(screen.nativeScale),
        @"safeArea": @{
            @"top": @(key.safeAreaInsets.top),
            @"bottom": @(key.safeAreaInsets.bottom),
            @"left": @(key.safeAreaInsets.left),
            @"right": @(key.safeAreaInsets.right),
        },
        @"orientation": @(device.orientation),
        @"interfaceStyle": @(key.traitCollection.userInterfaceStyle),
        @"frontmostApp": bundleID ?: @"",
    };
}

#pragma mark - 对外

@implementation FPLayoutSnapshot

+ (NSString *)defaultCaptureDirectory {
    NSString *stamp = [NSString stringWithFormat:@"%.0f", NSDate.date.timeIntervalSince1970 * 1000];
    return [NSTemporaryDirectory()
        stringByAppendingPathComponent:[NSString stringWithFormat:@"FlexProbe-captures/%@", stamp]];
}

+ (NSArray<NSString *> *)captureIntoDirectory:(NSString *)dir {
    if (![NSThread isMainThread]) {
        NSLog(@"[FlexProbe] captureIntoDirectory 必须在主线程调用");
        return @[];
    }

    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil]) {
        return @[];
    }

    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;

    // ── 1. 视图树(全部窗口,按 windowLevel 排序) ──
    NSMutableString *tree = [NSMutableString string];
    NSMutableArray<NSMutableDictionary *> *windowsJSON = [NSMutableArray array];

    NSArray<UIWindow *> *windows = nil;
    UIWindow *key = FPKeyWindow();
    if (@available(iOS 13.0, *)) {
        NSMutableArray<UIWindowScene *> *scenes = [NSMutableArray array];
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:UIWindowScene.class]) [scenes addObject:(UIWindowScene *)scene];
        }
        NSMutableArray<UIWindow *> *all = [NSMutableArray array];
        for (UIWindowScene *scene in scenes) [all addObjectsFromArray:scene.windows];
        [all sortUsingComparator:^NSComparisonResult(UIWindow *a, UIWindow *b) {
            if (a.windowLevel == b.windowLevel) return NSOrderedSame;
            return a.windowLevel < b.windowLevel ? NSOrderedAscending : NSOrderedDescending;
        }];
        windows = all;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (windows.count == 0) {
        windows = UIApplication.sharedApplication.windows;
    }
#pragma clang diagnostic pop

    NSUInteger total = 0;
    for (UIWindow *window in windows) {
        [tree appendFormat:@"[WINDOW %@ %p] level=%.0f frame=%@ key=%d rootVC=%@\n",
            NSStringFromClass(window.class), window, window.windowLevel,
            FPRectString(window.frame), window.isKeyWindow,
            window.rootViewController ? NSStringFromClass(window.rootViewController.class) : @"(nil)"];

        NSMutableDictionary *windowJSON = [NSMutableDictionary dictionary];
        windowJSON[@"class"] = NSStringFromClass(window.class);
        windowJSON[@"level"] = @((double)window.windowLevel);
        windowJSON[@"frame"] = FPRectDict(window.frame);
        windowJSON[@"key"] = @(window.isKeyWindow);
        if (window.rootViewController) {
            windowJSON[@"rootViewController"] = NSStringFromClass(window.rootViewController.class);
        }
        NSMutableArray<NSMutableDictionary *> *children = [NSMutableArray array];
        total = FPDumpView(window, 1, window, tree, children, &total);
        if (children.count) windowJSON[@"subviews"] = children;
        [windowsJSON addObject:windowJSON];
    }
    [tree appendFormat:@"\n(共 %lu 个视图节点,窗口 %lu 个;上限 %lu,超出部分截断)\n",
        (unsigned long)total, (unsigned long)windows.count, (unsigned long)kFPMaxNodes];

    // ── 2. 控制器树 ──
    NSMutableString *vcTree = [NSMutableString string];
    NSMutableArray<NSMutableDictionary *> *vcsJSON = [NSMutableArray array];
    for (UIWindow *window in windows) {
        if (!window.rootViewController) continue;
        [vcTree appendFormat:@"[WINDOW rootVC]\n"];
        FPDumpViewController(window.rootViewController, 1, vcTree, vcsJSON);
    }
    if (vcTree.length == 0) [vcTree appendString:@"(无 rootViewController)\n"];

    // ── 3. meta ──
    NSDictionary *meta = FPMetaDictionary(bundleID);
    NSMutableString *metaText = [NSMutableString string];
    for (NSString *line in @[
        @"── FlexProbe 布局快照 ──",
        [NSString stringWithFormat:@"capturedAt: %@", meta[@"capturedAt"]],
        [NSString stringWithFormat:@"bundleID: %@ (%@ build %@)",
            meta[@"bundleID"], meta[@"appVersion"], meta[@"appBuild"]],
        [NSString stringWithFormat:@"system: iOS %@", meta[@"systemVersion"]],
        [NSString stringWithFormat:@"device: %@", meta[@"deviceModel"]],
        [NSString stringWithFormat:@"screen: %@ scale=%.0f native=%.0f",
            meta[@"screenBounds"], [meta[@"screenScale"] doubleValue], [meta[@"screenNativeScale"] doubleValue]],
        [NSString stringWithFormat:@"safeArea: %@",
            ((NSDictionary *)meta[@"safeArea"]) ?: @{}],
        [NSString stringWithFormat:@"orientation: %@  interfaceStyle: %@",
            meta[@"orientation"], meta[@"interfaceStyle"]],
    ]) {
        [metaText appendFormat:@"%@\n", line];
    }

    // ── 4. 落盘 ──
    NSDictionary *jsonRoot = @{ @"meta": meta, @"windows": windowsJSON, @"viewControllers": vcsJSON };
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonRoot
                                                       options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                         error:&jsonError];

    NSMutableArray<NSString *> *files = [NSMutableArray array];
    void (^write)(NSString *, NSData *) = ^(NSString *name, NSData *data) {
        if (!data) return;
        NSString *path = [dir stringByAppendingPathComponent:name];
        if ([data writeToFile:path atomically:YES]) [files addObject:path];
    };
    write(kFPMetaFile, [metaText dataUsingEncoding:NSUTF8StringEncoding]);
    write(kFTreeFile, [tree dataUsingEncoding:NSUTF8StringEncoding]);
    write(kFVCTreeFile, [vcTree dataUsingEncoding:NSUTF8StringEncoding]);
    write(kFJSONFile, jsonData);
    (void)FPDocumentDirectory;
    (void)key;
    return files;
}

@end
