#import <UIKit/UIKit.h>
#import "FLEXDebugCapture.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLEXDebugExportResult : NSObject

@property (nonatomic, strong) NSURL *zipURL;
@property (nonatomic, strong) NSURL *workingDirectoryURL;
@property (nonatomic, copy) NSString *summary;

@end

#ifdef __cplusplus
extern "C" {
#endif

/// 生成包含 UI 布局、配置诊断、网络拦截、系统 Log 的标准调试 Zip 包
FLEXDebugExportResult * _Nullable FLEXDebugCreateExportPackage(FLEXDebugCaptureContext *context, NSError **error);

/// 弹出系统分享弹窗 (AirDrop, 存储到文件, Filza, 微信等)
void FLEXDebugPresentShareSheet(FLEXDebugExportResult *result, UIViewController *presenter);

/// 清理导出临时目录
void FLEXDebugCleanupExport(FLEXDebugExportResult * _Nullable result);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
