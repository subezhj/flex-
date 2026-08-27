//
//  FPZipWriter.m
//  FlexProbe(移植自 DYKiller DKZipWriter)
//
//  布局快照导出使用的最小 ZIP 写入器(Stored + zlib CRC32 + ZIP64 条目计数)。
//

#import "FPZipWriter.h"
#import <CoreFoundation/CoreFoundation.h>
#import <zlib.h>

static void FPZipAppendUInt16(NSMutableData *data, uint16_t value) {
    uint16_t v = CFSwapInt16HostToLittle(value);
    [data appendBytes:&v length:sizeof(v)];
}

static void FPZipAppendUInt32(NSMutableData *data, uint32_t value) {
    uint32_t v = CFSwapInt32HostToLittle(value);
    [data appendBytes:&v length:sizeof(v)];
}

static void FPZipAppendUInt64(NSMutableData *data, uint64_t value) {
    uint64_t v = CFSwapInt64HostToLittle(value);
    [data appendBytes:&v length:sizeof(v)];
}

static NSString *FPZipRelativePath(NSString *path, NSString *rootDir) {
    NSString *prefix = [rootDir stringByAppendingString:@"/"];
    if ([path hasPrefix:prefix]) return [path substringFromIndex:prefix.length];
    return path.lastPathComponent ?: @"file";
}

static NSError *FPZipError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"FlexProbe.Zip" code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"ZIP failed"}];
}

static NSData *FPZipLocalHeader(NSData *nameData, uint32_t crc, uint32_t size) {
    NSMutableData *d = [NSMutableData data];
    FPZipAppendUInt32(d, 0x04034b50);
    FPZipAppendUInt16(d, 20);
    FPZipAppendUInt16(d, 0x0800);
    FPZipAppendUInt16(d, 0);
    FPZipAppendUInt16(d, 0);
    FPZipAppendUInt16(d, 0);
    FPZipAppendUInt32(d, crc);
    FPZipAppendUInt32(d, size);
    FPZipAppendUInt32(d, size);
    FPZipAppendUInt16(d, (uint16_t)nameData.length);
    FPZipAppendUInt16(d, 0);
    [d appendData:nameData];
    return d;
}

static NSData *FPZipCentralHeader(NSData *nameData, uint32_t crc, uint32_t size, uint32_t offset) {
    NSMutableData *d = [NSMutableData data];
    FPZipAppendUInt32(d, 0x02014b50);
    FPZipAppendUInt16(d, 20);
    FPZipAppendUInt16(d, 20);
    FPZipAppendUInt16(d, 0x0800);
    FPZipAppendUInt16(d, 0);
    FPZipAppendUInt16(d, 0);
    FPZipAppendUInt16(d, 0);
    FPZipAppendUInt32(d, crc);
    FPZipAppendUInt32(d, size);
    FPZipAppendUInt32(d, size);
    FPZipAppendUInt16(d, (uint16_t)nameData.length);
    FPZipAppendUInt16(d, 0);
    FPZipAppendUInt16(d, 0);
    FPZipAppendUInt16(d, 0);
    FPZipAppendUInt16(d, 0);
    FPZipAppendUInt32(d, 0);
    FPZipAppendUInt32(d, offset);
    [d appendData:nameData];
    return d;
}

static NSData *FPZipEndRecords(uint64_t entryCount, uint64_t centralSize, uint64_t centralOffset) {
    NSMutableData *end = [NSMutableData data];
    BOOL needsZip64 = entryCount >= UINT16_MAX;
    if (needsZip64) {
        uint64_t zip64EndOffset = centralOffset + centralSize;
        FPZipAppendUInt32(end, 0x06064b50);
        FPZipAppendUInt64(end, 44);
        FPZipAppendUInt16(end, 45);
        FPZipAppendUInt16(end, 45);
        FPZipAppendUInt32(end, 0);
        FPZipAppendUInt32(end, 0);
        FPZipAppendUInt64(end, entryCount);
        FPZipAppendUInt64(end, entryCount);
        FPZipAppendUInt64(end, centralSize);
        FPZipAppendUInt64(end, centralOffset);

        FPZipAppendUInt32(end, 0x07064b50);
        FPZipAppendUInt32(end, 0);
        FPZipAppendUInt64(end, zip64EndOffset);
        FPZipAppendUInt32(end, 1);
    }

    uint16_t legacyEntryCount = entryCount >= UINT16_MAX ? UINT16_MAX : (uint16_t)entryCount;
    FPZipAppendUInt32(end, 0x06054b50);
    FPZipAppendUInt16(end, 0);
    FPZipAppendUInt16(end, 0);
    FPZipAppendUInt16(end, legacyEntryCount);
    FPZipAppendUInt16(end, legacyEntryCount);
    FPZipAppendUInt32(end, (uint32_t)centralSize);
    FPZipAppendUInt32(end, (uint32_t)centralOffset);
    FPZipAppendUInt16(end, 0);
    return end;
}

@implementation FPZipWriter

+ (BOOL)createZipAtPath:(NSString *)zipPath
                rootDir:(NSString *)rootDir
                  files:(NSArray<NSString *> *)files
               progress:(FPZipProgressBlock)progress
                  error:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *parent = zipPath.stringByDeletingLastPathComponent;
    if (parent.length) {
        NSError *dirError = nil;
        if (![fm createDirectoryAtPath:parent withIntermediateDirectories:YES attributes:nil error:&dirError] && dirError) {
            if (error) *error = dirError;
            return NO;
        }
    }

    [fm removeItemAtPath:zipPath error:nil];
    if (![fm createFileAtPath:zipPath contents:NSData.data attributes:nil]) {
        if (error) {
            *error = [NSError errorWithDomain:@"FlexProbe.Zip"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"ZIP file creation failed"}];
        }
        return NO;
    }

    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:zipPath];
    if (!handle) {
        if (error) {
            *error = [NSError errorWithDomain:@"FlexProbe.Zip"
                                         code:-2
                                     userInfo:@{NSLocalizedDescriptionKey: @"ZIP file handle creation failed"}];
        }
        return NO;
    }

    NSMutableData *central = [NSMutableData data];
    NSMutableSet<NSString *> *seenPaths = [NSMutableSet set];
    uint32_t offset = 0;
    uint64_t entryCount = 0;
    NSUInteger total = files.count;
    NSUInteger done = 0;

    for (NSString *file in files) {
        NSError *entryError = nil;
        @autoreleasepool {
            do {
                BOOL isDir = NO;
                if (![fm fileExistsAtPath:file isDirectory:&isDir] || isDir) {
                    entryError = FPZipError(-3, [NSString stringWithFormat:@"ZIP source file missing: %@", file]);
                    break;
                }

                NSString *relative = FPZipRelativePath(file, rootDir);
                if ([seenPaths containsObject:relative]) {   // 同一相对路径只写最终文件内容一次
                    done++;
                    break;
                }
                [seenPaths addObject:relative];
                NSData *content = [NSData dataWithContentsOfFile:file];
                NSData *nameData = [relative dataUsingEncoding:NSUTF8StringEncoding];
                if (!content || !nameData.length || nameData.length > UINT16_MAX || content.length > UINT32_MAX) {
                    entryError = FPZipError(-4, [NSString stringWithFormat:@"ZIP entry unsupported: %@", relative]);
                    break;
                }

                uint32_t size = (uint32_t)content.length;
                uint32_t crc = (uint32_t)crc32(0, content.bytes, (uInt)content.length);
                NSData *local = FPZipLocalHeader(nameData, crc, size);
                if (local.length + content.length > UINT32_MAX - offset) {
                    entryError = FPZipError(-8, @"ZIP32 data offset overflow");
                    break;
                }
                @try {
                    [handle writeData:local];
                    [handle writeData:content];
                } @catch (NSException *exception) {
                    entryError = FPZipError(-5, exception.reason ?: @"ZIP entry write failed");
                    break;
                }
                [central appendData:FPZipCentralHeader(nameData, crc, size, offset)];

                offset += (uint32_t)(local.length + content.length);
                entryCount++;
                done++;
                if (progress) progress((CGFloat)done / (CGFloat)MAX(total, 1));
            } while (NO);
        }
        if (entryError) {
            [handle closeFile];
            if (error) *error = entryError;
            return NO;
        }
    }

    if (central.length > UINT32_MAX) {
        [handle closeFile];
        if (error) *error = FPZipError(-9, @"ZIP32 central directory overflow");
        return NO;
    }
    uint64_t centralOffset = offset;
    uint64_t centralSize = central.length;
    @try {
        [handle writeData:central];
    } @catch (NSException *exception) {
        [handle closeFile];
        if (error) *error = FPZipError(-6, exception.reason ?: @"ZIP central directory write failed");
        return NO;
    }
    NSData *end = FPZipEndRecords(entryCount, centralSize, centralOffset);
    @try {
        [handle writeData:end];
    } @catch (NSException *exception) {
        [handle closeFile];
        if (error) *error = FPZipError(-7, exception.reason ?: @"ZIP footer write failed");
        return NO;
    }
    [handle closeFile];
    return YES;
}

@end
