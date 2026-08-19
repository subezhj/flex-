#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXDebugCaptureContext : NSObject

@property (nonatomic, strong) NSDictionary *metadata;
@property (nonatomic, strong) NSArray *windowsJSON;
@property (nonatomic, strong) NSDictionary *viewTreeJSON;
@property (nonatomic, copy) NSString *viewTreeText;
@property (nonatomic, copy) NSString *viewControllersText;
@property (nonatomic, strong) NSArray<NSString *> *pageClassNames;
@property (nonatomic, strong, nullable) NSData *screenshotPNG;
@property (nonatomic, strong, nullable) NSData *wireframePNG;

@end

#ifdef __cplusplus
extern "C" {
#endif

/// 抓取前台活动窗口（排除 FLEX 自身窗口）
NSArray<UIWindow *> *FLEXDebugActiveWindows(void);

/// 获取最顶层 View Controller
UIViewController *FLEXDebugTopViewController(UIWindow * _Nullable window);

/// 抓取当前屏幕布局与运行时快照
FLEXDebugCaptureContext *FLEXDebugCaptureCurrentContext(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
