//
//  FPLayoutSnapshot.h
//  FlexProbe
//
//  布局快照采集:把当前 App 全部窗口的视图树 / 控制器树 / 屏幕信息
//  落盘为 meta.txt + layout-tree.txt + vc-tree.txt + layout.json。
//  供打包为 zip 后发送到 PC/WSL 侧离线分析。
//
//  必须在主线程调用(遍历 UIKit 对象)。
//

#ifndef FPLayoutSnapshot_h
#define FPLayoutSnapshot_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FPLayoutSnapshot : NSObject

/// 默认采集目录:NSTemporaryDirectory()/FlexProbe-captures/<时间戳>
+ (NSString *)defaultCaptureDirectory;

/// 采集快照到 dir(自动创建),返回生成的文件绝对路径数组(不含 zip)。
/// 内部有节点数上限(30000)与深度上限(64),超大视图树只截取前面部分。
+ (NSArray<NSString *> *)captureIntoDirectory:(NSString *)dir;

@end

NS_ASSUME_NONNULL_END

#endif /* FPLayoutSnapshot_h */
