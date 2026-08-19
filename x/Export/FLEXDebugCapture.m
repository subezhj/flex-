#import "FLEXDebugCapture.h"
#import "FLEXUtility.h"
#import <objc/runtime.h>

@implementation FLEXDebugCaptureContext
@end

NSArray<UIWindow *> *FLEXDebugActiveWindows(void) {
    NSMutableArray<UIWindow *> *result = [NSMutableArray array];
    
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] &&
                scene.activationState == UISceneActivationStateForegroundActive) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *w in ws.windows) {
                    if (w && ![NSStringFromClass(w.class) containsString:@"FLEXWindow"]) {
                        [result addObject:w];
                    }
                }
            }
        }
    }
    
    if (result.count == 0) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w && ![NSStringFromClass(w.class) containsString:@"FLEXWindow"]) {
                [result addObject:w];
            }
        }
#pragma clang diagnostic pop
    }
    
    return result;
}

UIViewController *FLEXDebugTopViewController(UIWindow *window) {
    UIWindow *targetWindow = window ?: [UIApplication sharedApplication].keyWindow;
    if (!targetWindow || [NSStringFromClass(targetWindow.class) containsString:@"FLEXWindow"]) {
        for (UIWindow *w in FLEXDebugActiveWindows()) {
            if (w.isKeyWindow) {
                targetWindow = w;
                break;
            }
        }
        if (!targetWindow) {
            targetWindow = FLEXDebugActiveWindows().firstObject;
        }
    }
    
    UIViewController *topVC = targetWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    
    if ([topVC isKindOfClass:[UINavigationController class]]) {
        topVC = [(UINavigationController *)topVC topViewController];
    } else if ([topVC isKindOfClass:[UITabBarController class]]) {
        topVC = [(UITabBarController *)topVC selectedViewController];
    }
    
    return topVC;
}

static NSDictionary *FLEXDumpViewToJSON(UIView *view, NSMutableSet<NSString *> *classNamesSet, NSInteger depth) {
    if (!view || depth > 30) return @{};
    
    NSString *className = NSStringFromClass([view class]);
    if (className) [classNamesSet addObject:className];
    
    CGRect frame = view.frame;
    CGRect bounds = view.bounds;
    
    NSMutableArray *subviewsJSON = [NSMutableArray array];
    for (UIView *sub in view.subviews) {
        NSDictionary *childDict = FLEXDumpViewToJSON(sub, classNamesSet, depth + 1);
        if (childDict.count > 0) {
            [subviewsJSON addObject:childDict];
        }
    }
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:@{
        @"class": className ?: @"Unknown",
        @"address": [NSString stringWithFormat:@"%p", view],
        @"frame": NSStringFromCGRect(frame),
        @"bounds": NSStringFromCGRect(bounds),
        @"hidden": @(view.hidden),
        @"alpha": @(view.alpha),
        @"userInteractionEnabled": @(view.userInteractionEnabled),
        @"subviewsCount": @(view.subviews.count),
    }];
    
    if (view.tag != 0) {
        dict[@"tag"] = @(view.tag);
    }
    
    UIViewController *vc = [FLEXUtility viewControllerForView:view];
    if (vc) {
        NSString *vcClass = NSStringFromClass([vc class]);
        dict[@"viewController"] = vcClass;
        [classNamesSet addObject:vcClass];
    }
    
    if (subviewsJSON.count > 0) {
        dict[@"subviews"] = subviewsJSON;
    }
    
    return dict;
}

static void FLEXDumpViewToText(UIView *view, NSMutableString *buffer, NSInteger depth) {
    if (!view || depth > 30) return;
    
    NSMutableString *indent = [NSMutableString string];
    for (NSInteger i = 0; i < depth; i++) {
        [indent appendString:@"  | "];
    }
    
    NSString *className = NSStringFromClass([view class]);
    CGRect f = view.frame;
    UIViewController *vc = [FLEXUtility viewControllerForView:view];
    NSString *vcInfo = vc ? [NSString stringWithFormat:@" (VC: %@)", NSStringFromClass([vc class])] : @"";
    
    [buffer appendFormat:@"%@%@ <%p> frame=(%.1f, %.1f, %.1f, %.1f)%@%@\n",
     indent,
     className,
     view,
     f.origin.x, f.origin.y, f.size.width, f.size.height,
     view.hidden ? @" [HIDDEN]" : @"",
     vcInfo];
    
    for (UIView *sub in view.subviews) {
        FLEXDumpViewToText(sub, buffer, depth + 1);
    }
}

static void FLEXDumpVCToText(UIViewController *vc, NSMutableString *buffer, NSInteger depth) {
    if (!vc || depth > 20) return;
    
    NSMutableString *indent = [NSMutableString string];
    for (NSInteger i = 0; i < depth; i++) {
        [indent appendString:@"  * "];
    }
    
    [buffer appendFormat:@"%@%@ <%p> title='%@'\n", indent, NSStringFromClass([vc class]), vc, vc.title ?: @""];
    
    for (UIViewController *child in vc.childViewControllers) {
        FLEXDumpVCToText(child, buffer, depth + 1);
    }
    
    if (vc.presentedViewController) {
        [buffer appendFormat:@"%@  [Presented] 👇\n", indent];
        FLEXDumpVCToText(vc.presentedViewController, buffer, depth + 1);
    }
}

static UIImage *FLEXTakeScreenshot(UIWindow *window) {
    UIScreen *screen = [UIScreen mainScreen];
    CGRect bounds = screen.bounds;
    
    if (@available(iOS 10.0, *)) {
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:bounds];
        return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
            for (UIWindow *w in FLEXDebugActiveWindows()) {
                if (!w.hidden && w.alpha > 0.01) {
                    [w drawViewHierarchyInRect:w.bounds afterScreenUpdates:NO];
                }
            }
        }];
    } else {
        UIGraphicsBeginImageContextWithOptions(bounds.size, YES, 0.0);
        for (UIWindow *w in FLEXDebugActiveWindows()) {
            if (!w.hidden && w.alpha > 0.01) {
                [w drawViewHierarchyInRect:w.bounds afterScreenUpdates:NO];
            }
        }
        UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return img;
    }
}

static void FLEXDrawWireframeForView(UIView *view, CGContextRef ctx, NSInteger depth) {
    if (!view || view.hidden || view.alpha < 0.01 || depth > 25) return;
    
    CGRect windowFrame = [view convertRect:view.bounds toView:nil];
    
    CGFloat hue = fmod(depth * 0.13, 1.0);
    UIColor *color = [UIColor colorWithHue:hue saturation:0.9 brightness:0.9 alpha:0.7];
    CGContextSetStrokeColorWithColor(ctx, color.CGColor);
    CGContextSetLineWidth(ctx, 1.0);
    CGContextStrokeRect(ctx, windowFrame);
    
    for (UIView *sub in view.subviews) {
        FLEXDrawWireframeForView(sub, ctx, depth + 1);
    }
}

static UIImage *FLEXRenderWireframe(void) {
    CGRect bounds = [UIScreen mainScreen].bounds;
    UIGraphicsBeginImageContextWithOptions(bounds.size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.1 alpha:1.0].CGColor);
    CGContextFillRect(ctx, bounds);
    
    for (UIWindow *w in FLEXDebugActiveWindows()) {
        FLEXDrawWireframeForView(w, ctx, 0);
    }
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

FLEXDebugCaptureContext *FLEXDebugCaptureCurrentContext(void) {
    FLEXDebugCaptureContext *context = [FLEXDebugCaptureContext new];
    NSMutableSet<NSString *> *classNamesSet = [NSMutableSet set];
    
    NSArray<UIWindow *> *windows = FLEXDebugActiveWindows();
    NSMutableArray *windowsJSON = [NSMutableArray array];
    NSMutableString *viewTreeText = [NSMutableString string];
    
    for (UIWindow *w in windows) {
        [windowsJSON addObject:@{
            @"class": NSStringFromClass([w class]) ?: @"UIWindow",
            @"address": [NSString stringWithFormat:@"%p", w],
            @"frame": NSStringFromCGRect(w.frame),
            @"isKey": @(w.isKeyWindow),
            @"level": @(w.windowLevel),
            @"hidden": @(w.hidden),
        }];
        
        [viewTreeText appendFormat:@"=== Window: %@ <%p> ===\n", NSStringFromClass([w class]), w];
        FLEXDumpViewToText(w, viewTreeText, 0);
        [viewTreeText appendString:@"\n"];
    }
    context.windowsJSON = windowsJSON;
    context.viewTreeText = [viewTreeText copy];
    
    UIWindow *targetWindow = windows.firstObject;
    if (targetWindow) {
        context.viewTreeJSON = FLEXDumpViewToJSON(targetWindow, classNamesSet, 0);
    }
    
    UIViewController *topVC = FLEXDebugTopViewController(targetWindow);
    NSMutableString *vcText = [NSMutableString string];
    if (topVC) {
        UIViewController *rootVC = targetWindow.rootViewController ?: topVC;
        [vcText appendFormat:@"=== Root ViewController: %@ ===\n", NSStringFromClass([rootVC class])];
        FLEXDumpVCToText(rootVC, vcText, 0);
    } else {
        [vcText appendString:@"No active top ViewController found.\n"];
    }
    context.viewControllersText = [vcText copy];
    
    context.pageClassNames = [[classNamesSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    UIImage *screenshot = FLEXTakeScreenshot(targetWindow);
    if (screenshot) {
        context.screenshotPNG = UIImagePNGRepresentation(screenshot);
    }
    
    UIImage *wireframe = FLEXRenderWireframe();
    if (wireframe) {
        context.wireframePNG = UIImagePNGRepresentation(wireframe);
    }
    
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    context.metadata = @{
        @"bundleID": [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown",
        @"appName": infoDict[@"CFBundleDisplayName"] ?: infoDict[@"CFBundleName"] ?: @"App",
        @"appVersion": infoDict[@"CFBundleShortVersionString"] ?: @"1.0",
        @"appBuild": infoDict[@"CFBundleVersion"] ?: @"1",
        @"systemVersion": [[UIDevice currentDevice] systemVersion] ?: @"iOS",
        @"deviceModel": [[UIDevice currentDevice] model] ?: @"iPhone",
        @"timestamp": @((long long)[[NSDate date] timeIntervalSince1970]),
        @"formattedDate": [[NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterLongStyle] copy] ?: @"",
        @"topViewController": topVC ? NSStringFromClass([topVC class]) : @"None",
        @"windowCount": @(windows.count),
    };
    
    return context;
}
