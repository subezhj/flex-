#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UCLayoutDumpTool : NSObject

+ (void)presentDumpPanelFromViewController:(nullable UIViewController *)viewController;
+ (void)performFullLayoutDumpAndShareFromViewController:(nullable UIViewController *)viewController;
+ (void)performQuickScreenshotShareFromViewController:(nullable UIViewController *)viewController;

@end

NS_ASSUME_NONNULL_END
