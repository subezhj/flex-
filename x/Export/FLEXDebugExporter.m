#import "FLEXDebugExporter.h"
#import "x/ClassDump/CDZipWriter.h"
#import "FLEXNetworkRecorder.h"
#import "FLEXNetworkTransaction.h"
#import "FLEXNetworkObserver.h"
#import "FLEXSystemLogMessage.h"
#import "FLEXManager+ThreeFingerTap.h"
#import <MobileCoreServices/MobileCoreServices.h>

@implementation FLEXDebugExportResult
@end

static NSDictionary *FLEXCollectConfigurationDiagnostics(void) {
    NSMutableDictionary *configDict = [NSMutableDictionary dictionary];
    
    // 1. App 环境与沙盒路径
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSDictionary *infoDict = [mainBundle infoDictionary];
    
    configDict[@"appInfo"] = @{
        @"bundleID": [mainBundle bundleIdentifier] ?: @"unknown",
        @"bundlePath": [mainBundle bundlePath] ?: @"",
        @"executablePath": [mainBundle executablePath] ?: @"",
        @"appName": infoDict[@"CFBundleDisplayName"] ?: infoDict[@"CFBundleName"] ?: @"App",
        @"appVersion": infoDict[@"CFBundleShortVersionString"] ?: @"1.0",
        @"appBuild": infoDict[@"CFBundleVersion"] ?: @"1",
        @"sandboxHome": NSHomeDirectory() ?: @"",
        @"documentsPath": NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject ?: @"",
        @"cachesPath": NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject ?: @"",
        @"tmpPath": NSTemporaryDirectory() ?: @"",
    };
    
    // 2. 设备与系统状态
    UIScreen *screen = [UIScreen mainScreen];
    CGRect bounds = screen.bounds;
    UIEdgeInsets safeInsets = UIEdgeInsetsZero;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if (@available(iOS 11.0, *)) {
        safeInsets = [UIApplication sharedApplication].keyWindow.safeAreaInsets;
    }
#endif
    
    configDict[@"deviceDiagnostics"] = @{
        @"systemName": [[UIDevice currentDevice] systemName] ?: @"iOS",
        @"systemVersion": [[UIDevice currentDevice] systemVersion] ?: @"",
        @"model": [[UIDevice currentDevice] model] ?: @"iPhone",
        @"name": [[UIDevice currentDevice] name] ?: @"",
        @"screenBounds": NSStringFromCGRect(bounds),
        @"screenScale": @(screen.scale),
        @"safeAreaInsets": NSStringFromUIEdgeInsets(safeInsets),
    };
    
    // 3. 配置诊断与已知异常定位
    NSMutableArray<NSString *> *issuesFound = [NSMutableArray array];
    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) {
        [issuesFound addObject:@"⚠️ KeyWindow 缺失: UIApplication.sharedApplication.keyWindow 为 nil"];
    } else if ([NSStringFromClass(keyWindow.class) containsString:@"FLEXWindow"]) {
        [issuesFound addObject:@"⚠️ Window 异常: 当前 KeyWindow 为 FLEX++ 悬浮窗口，宿主 App 视角可能丢失层级"];
    }
    
    if (keyWindow && !keyWindow.rootViewController) {
        [issuesFound addObject:@"⚠️ RootVC 异常: 当前主窗口 rootViewController 为 nil"];
    }
    
    BOOL isThreeFingerEnabled = [FLEXManager isThreeFingerTapEnabled];
    configDict[@"flexSettings"] = @{
        @"threeFingerTapEnabled": @(isThreeFingerEnabled),
        @"networkObserverEnabled": @([FLEXNetworkObserver isEnabled]),
    };
    
    if (!isThreeFingerEnabled) {
        [issuesFound addObject:@"💡 提示: 三指唤醒手势当前被用户设置为关闭状态"];
    }
    
    configDict[@"diagnosticIssues"] = [issuesFound copy];
    
    // 4. NSUserDefaults 核心键值诊断 (过滤大体积敏感字段)
    NSDictionary *userDefaultsDict = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    NSMutableDictionary *safeDefaults = [NSMutableDictionary dictionary];
    [userDefaultsDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([key isKindOfClass:[NSString class]]) {
            NSString *keyStr = (NSString *)key;
            if ([keyStr hasPrefix:@"FLEX"] || [keyStr hasPrefix:@"DK"] || [keyStr containsString:@"Debug"] || [keyStr containsString:@"Config"]) {
                safeDefaults[keyStr] = [obj description];
            }
        }
    }];
    configDict[@"userDefaultsDiagnostics"] = [safeDefaults copy];
    
    return [configDict copy];
}

static NSArray *FLEXCollectNetworkTransactionsJSON(void) {
    NSArray<FLEXHTTPTransaction *> *transactions = [FLEXNetworkRecorder defaultRecorder].HTTPTransactions;
    NSMutableArray *result = [NSMutableArray array];
    
    for (FLEXHTTPTransaction *transaction in transactions) {
        if (!transaction) continue;
        
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[@"requestID"] = transaction.requestID ?: @"";
        dict[@"url"] = transaction.request.URL.absoluteString ?: @"";
        dict[@"httpMethod"] = transaction.request.HTTPMethod ?: @"GET";
        dict[@"duration"] = @(transaction.duration);
        dict[@"receivedLength"] = @(transaction.receivedDataLength);
        dict[@"startTime"] = transaction.startTime ? @(transaction.startTime.timeIntervalSince1970) : @(0);
        
        if (transaction.request.allHTTPHeaderFields) {
            dict[@"requestHeaders"] = transaction.request.allHTTPHeaderFields;
        }
        
        if ([transaction.response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)transaction.response;
            dict[@"statusCode"] = @(httpResp.statusCode);
            dict[@"mimeType"] = httpResp.MIMEType ?: @"";
            if (httpResp.allHeaderFields) {
                dict[@"responseHeaders"] = httpResp.allHeaderFields;
            }
        }
        
        [result addObject:dict];
    }
    
    return [result copy];
}

static NSString *FLEXCollectSystemLogsText(void) {
    NSMutableString *logText = [NSMutableString string];
    [logText appendFormat:@"[FLEX++] Log Exporter Snapshot generated at %@\n", [NSDate date]];
    return [logText copy];
}

FLEXDebugExportResult *FLEXDebugCreateExportPackage(FLEXDebugCaptureContext *captureContext, NSError **error) {
    FLEXDebugCaptureContext *ctx = captureContext ?: FLEXDebugCaptureCurrentContext();
    
    NSString *timestamp = [NSString stringWithFormat:@"%ld", (long)[[NSDate date] timeIntervalSince1970]];
    NSString *dirName = [NSString stringWithFormat:@"FLEX_Debug_Dump_%@", timestamp];
    NSString *workDir = [NSTemporaryDirectory() stringByAppendingPathComponent:dirName];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *createDirErr = nil;
    if (![fm createDirectoryAtPath:workDir withIntermediateDirectories:YES attributes:nil error:&createDirErr]) {
        if (error) *error = createDirErr;
        return nil;
    }
    
    NSMutableArray<NSString *> *createdFilePaths = [NSMutableArray array];
    
    // 1. Metadata JSON
    NSData *metaData = [NSJSONSerialization dataWithJSONObject:ctx.metadata options:NSJSONWritingPrettyPrinted error:nil];
    if (metaData) {
        NSString *metaPath = [workDir stringByAppendingPathComponent:@"metadata.json"];
        if ([metaData writeToFile:metaPath atomically:YES]) [createdFilePaths addObject:metaPath];
    }
    
    // 2. View Tree JSON & TXT
    if (ctx.viewTreeJSON) {
        NSData *vtData = [NSJSONSerialization dataWithJSONObject:ctx.viewTreeJSON options:NSJSONWritingPrettyPrinted error:nil];
        if (vtData) {
            NSString *vtPath = [workDir stringByAppendingPathComponent:@"view_tree.json"];
            if ([vtData writeToFile:vtPath atomically:YES]) [createdFilePaths addObject:vtPath];
        }
    }
    
    if (ctx.viewTreeText) {
        NSString *vttPath = [workDir stringByAppendingPathComponent:@"view_tree.txt"];
        if ([ctx.viewTreeText writeToFile:vttPath atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
            [createdFilePaths addObject:vttPath];
        }
    }
    
    // 3. ViewControllers TXT
    if (ctx.viewControllersText) {
        NSString *vcPath = [workDir stringByAppendingPathComponent:@"view_controllers.txt"];
        if ([ctx.viewControllersText writeToFile:vcPath atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
            [createdFilePaths addObject:vcPath];
        }
    }
    
    // 4. Page Class List TXT
    if (ctx.pageClassNames && ctx.pageClassNames.count > 0) {
        NSString *classesStr = [ctx.pageClassNames componentsJoinedByString:@"\n"];
        NSString *classesPath = [workDir stringByAppendingPathComponent:@"page_classes.txt"];
        if ([classesStr writeToFile:classesPath atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
            [createdFilePaths addObject:classesPath];
        }
    }
    
    // 5. Screenshot & Wireframe PNG
    if (ctx.screenshotPNG) {
        NSString *ssPath = [workDir stringByAppendingPathComponent:@"screenshot.png"];
        if ([ctx.screenshotPNG writeToFile:ssPath atomically:YES]) [createdFilePaths addObject:ssPath];
    }
    if (ctx.wireframePNG) {
        NSString *wfPath = [workDir stringByAppendingPathComponent:@"wireframe.png"];
        if ([ctx.wireframePNG writeToFile:wfPath atomically:YES]) [createdFilePaths addObject:wfPath];
    }
    
    // 6. Configuration Diagnostics JSON
    NSDictionary *configDict = FLEXCollectConfigurationDiagnostics();
    NSData *configData = [NSJSONSerialization dataWithJSONObject:configDict options:NSJSONWritingPrettyPrinted error:nil];
    if (configData) {
        NSString *configPath = [workDir stringByAppendingPathComponent:@"configuration.json"];
        if ([configData writeToFile:configPath atomically:YES]) [createdFilePaths addObject:configPath];
    }
    
    // 7. Network Intercepted Transactions JSON
    NSArray *netJSON = FLEXCollectNetworkTransactionsJSON();
    if (netJSON) {
        NSData *netData = [NSJSONSerialization dataWithJSONObject:netJSON options:NSJSONWritingPrettyPrinted error:nil];
        if (netData) {
            NSString *netPath = [workDir stringByAppendingPathComponent:@"network_transactions.json"];
            if ([netData writeToFile:netPath atomically:YES]) [createdFilePaths addObject:netPath];
        }
    }
    
    // 8. System Logs TXT
    NSString *logsText = FLEXCollectSystemLogsText();
    if (logsText) {
        NSString *logsPath = [workDir stringByAppendingPathComponent:@"system_logs.txt"];
        if ([logsText writeToFile:logsPath atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
            [createdFilePaths addObject:logsPath];
        }
    }
    
    // 9. 压缩打成 ZIP 包
    NSString *zipPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.zip", dirName]];
    NSError *zipError = nil;
    BOOL zipSuccess = [CDZipWriter createZipAtPath:zipPath rootDir:workDir files:createdFilePaths progress:nil error:&zipError];
    
    if (!zipSuccess) {
        if (error) *error = zipError;
        return nil;
    }
    
    FLEXDebugExportResult *result = [FLEXDebugExportResult new];
    result.zipURL = [NSURL fileURLWithPath:zipPath];
    result.workingDirectoryURL = [NSURL fileURLWithPath:workDir];
    result.summary = [NSString stringWithFormat:@"打包完成！抓取到 %lu 个组件与文件，网络拦截包含 %lu 条请求", (unsigned long)createdFilePaths.count, (unsigned long)netJSON.count];
    
    return result;
}

void FLEXDebugPresentShareSheet(FLEXDebugExportResult *result, UIViewController *presenter) {
    if (!result || !result.zipURL || !presenter) return;
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[result.zipURL] applicationActivities:nil];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = presenter.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1);
    }
    
    activityVC.completionWithItemsHandler = ^(UIActivityType _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
        FLEXDebugCleanupExport(result);
    };
    
    [presenter presentViewController:activityVC animated:YES completion:nil];
}

void FLEXDebugCleanupExport(FLEXDebugExportResult *result) {
    if (!result) return;
    NSFileManager *fm = [NSFileManager defaultManager];
    if (result.workingDirectoryURL) {
        [fm removeItemAtURL:result.workingDirectoryURL error:nil];
    }
}
