//
//  FPZipWriter.h
//  FlexProbe
//
//  移植自 DYKiller 的 DKZipWriter:最小 ZIP 写入器(Stored 条目 + zlib CRC32 + ZIP64 计数)。
//  无第三方依赖,便于随源码并入任意 Theos 工程。
//

#ifndef FPZipWriter_h
#define FPZipWriter_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^FPZipProgressBlock)(CGFloat progress);

@interface FPZipWriter : NSObject

/// 把 rootDir 下的 files 打包为 zipPath(不压缩,STORED)。
/// files 传相对 rootDir 的绝对路径,zip 内条目名取相对路径。
+ (BOOL)createZipAtPath:(NSString *)zipPath
                rootDir:(NSString *)rootDir
                  files:(NSArray<NSString *> *)files
               progress:(nullable FPZipProgressBlock)progress
                  error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

#endif /* FPZipWriter_h */
