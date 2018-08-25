//
//  JDRequest.m
//  JDNetWork
//
//  Created by JDragon on 2018/8/25.
//  Copyright © 2018年 JDragon. All rights reserved.
//

#import "JDNetworkConfig.h"
#import "JDRequest.h"
#import "JDNetworkPrivate.h"

#ifndef NSFoundationVersionNumber_iOS_8_0
#define NSFoundationVersionNumber_With_QoS_Available 1140.11
#else
#define NSFoundationVersionNumber_With_QoS_Available NSFoundationVersionNumber_iOS_8_0
#endif

NSString *const JDRequestCacheErrorDomain = @"com.yuantiku.request.caching";

static dispatch_queue_t JDrequest_cache_writing_queue() {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_attr_t attr = DISPATCH_QUEUE_SERIAL;
        if (NSFoundationVersionNumber >= NSFoundationVersionNumber_With_QoS_Available) {
            attr = dispatch_queue_attr_make_with_qos_class(attr, QOS_CLASS_BACKGROUND, 0);
        }
        queue = dispatch_queue_create("com.yuantiku.JDrequest.caching", attr);
    });

    return queue;
}

/**
 元数据，存储缓存的一些信息
 */
@interface JDCacheMetadata : NSObject<NSSecureCoding>

/**
 版本号
 */
@property (nonatomic, assign) long long version;

/**
 <#Description#>
 */
@property (nonatomic, strong) NSString *sensitiveDataString;

/**
 编码
 */
@property (nonatomic, assign) NSStringEncoding stringEncoding;

/**
 创建时间
 */
@property (nonatomic, strong) NSDate *creationDate;

/**
  app版本
 */
@property (nonatomic, strong) NSString *appVersionString;

@end

@implementation JDCacheMetadata

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:@(self.version) forKey:NSStringFromSelector(@selector(version))];
    [aCoder encodeObject:self.sensitiveDataString forKey:NSStringFromSelector(@selector(sensitiveDataString))];
    [aCoder encodeObject:@(self.stringEncoding) forKey:NSStringFromSelector(@selector(stringEncoding))];
    [aCoder encodeObject:self.creationDate forKey:NSStringFromSelector(@selector(creationDate))];
    [aCoder encodeObject:self.appVersionString forKey:NSStringFromSelector(@selector(appVersionString))];
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [self init];
    if (!self) {
        return nil;
    }

    self.version = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(version))] integerValue];
    self.sensitiveDataString = [aDecoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(sensitiveDataString))];
    self.stringEncoding = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(stringEncoding))] integerValue];
    self.creationDate = [aDecoder decodeObjectOfClass:[NSDate class] forKey:NSStringFromSelector(@selector(creationDate))];
    self.appVersionString = [aDecoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(appVersionString))];

    return self;
}

@end

@interface JDRequest()

@property (nonatomic, strong) NSData *cacheData;
@property (nonatomic, strong) NSString *cacheString;
@property (nonatomic, strong) id cacheJSON;
@property (nonatomic, strong) NSXMLParser *cacheXML;

@property (nonatomic, strong) JDCacheMetadata *cacheMetadata;
@property (nonatomic, assign) BOOL dataFromCache;

@end

@implementation JDRequest

- (void)start {
    if (self.ignoreCache) {// 如果忽略缓存，那就发起无缓存请求
        [self startWithoutCache];
        return;
    }

    // Do not cache download request.
    if (self.resumableDownloadPath) {// 下载请求，不进行缓存处理
        [self startWithoutCache];
        return;
    }

    if (![self loadCacheWithError:nil]) { // 如果加载缓存失败，则发起无缓存请求
        [self startWithoutCache];
        return;
    }

    _dataFromCache = YES;// 标记

    dispatch_async(dispatch_get_main_queue(), ^{
        [self requestCompletePreprocessor];
        [self requestCompleteFilter];
        JDRequest *strongSelf = self;
        // 回调
        [strongSelf.delegate requestFinished:strongSelf];
        if (strongSelf.successCompletionBlock) {
            strongSelf.successCompletionBlock(strongSelf);
        }
        // 清除block
        [strongSelf clearCompletionBlock];
    });
}

- (void)startWithoutCache {
    [self clearCacheVariables];
    [super start];
}

#pragma mark - Network Request Delegate

- (void)requestCompletePreprocessor {
    [super requestCompletePreprocessor];

    if (self.writeCacheAsynchronously) {
        dispatch_async(JDrequest_cache_writing_queue(), ^{// 异步存储内存
            [self saveResponseDataToCacheFile:[super responseData]];
        });
    } else {
        [self saveResponseDataToCacheFile:[super responseData]];
    }
}

#pragma mark - Subclass Override

- (NSInteger)cacheTimeInSeconds {
    return -1;
}

- (long long)cacheVersion {
    return 0;
}

- (id)cacheSensitiveData {
    return nil;
}

- (BOOL)writeCacheAsynchronously {
    return YES;
}

#pragma mark -

- (BOOL)isDataFromCache {
    return _dataFromCache;
}

- (NSData *)responseData {
    if (_cacheData) {
        return _cacheData;
    }
    return [super responseData];
}

- (NSString *)responseString {
    if (_cacheString) {
        return _cacheString;
    }
    return [super responseString];
}

- (id)responseJSONObject {
    if (_cacheJSON) {
        return _cacheJSON;
    }
    return [super responseJSONObject];
}

- (id)responseObject {
    if (_cacheJSON) {
        return _cacheJSON;
    }
    if (_cacheXML) {
        return _cacheXML;
    }
    if (_cacheData) {
        return _cacheData;
    }
    return [super responseObject];
}

#pragma mark -
/// 加载缓存
- (BOOL)loadCacheWithError:(NSError * _Nullable __autoreleasing *)error {
    // Make sure cache time in valid.
    // 如果缓存时间小于0，则无效
    if ([self cacheTimeInSeconds] < 0) {
        if (error) {
//            *error = [NSError errorWithDomain:JDRequestCacheErrorDomain code:JDRequestCacheErrorInvalidCacheTime userInfo:@{ NSLocalizedDescriptionKey:@"Invalid cache time"}];
             *error = [NSError errorWithDomain:JDRequestCacheErrorDomain code:JDRequestCacheErrorInvalidCacheTime userInfo:@{ NSLocalizedDescriptionKey:@"缓存时间小于0，无效!"}];
            NSString *str = [NSString stringWithFormat:@"缓存读取失败,原因: %@",*error];
            JDNetLog(@"%@",str);
            [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];
        }
        return NO;
    }

    // Try load metadata.
    // 加载元数据
    if (![self loadCacheMetadata]) {
        *error = [NSError errorWithDomain:JDRequestCacheErrorDomain code:JDRequestCacheErrorInvalidMetadata userInfo:@{ NSLocalizedDescriptionKey:@"不可用的元数据，缓存可能不存在"}];
        if (error) {
            NSString *str = [NSString stringWithFormat:@"缓存读取失败,原因: %@",*error];
            JDNetLog(@"%@",str);
            [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];

        }
        return NO;
    }

    // Check if cache is still valid. 检查缓存是否可用
    if (![self validateCacheWithError:error]) {
        if (error) {
            NSString *str = [NSString stringWithFormat:@"缓存读取失败,原因: %@",*error];
            JDNetLog(@"%@",str);
            [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];
        }
        return NO;
    }

    // Try load cache. 加载缓存
    if (![self loadCacheData]) {
        if (error) {
        
            *error = [NSError errorWithDomain:JDRequestCacheErrorDomain code:JDRequestCacheErrorInvalidCacheData userInfo:@{ NSLocalizedDescriptionKey:@"缓存不可用"}];
            if (error) {
                NSString *str = [NSString stringWithFormat:@"缓存读取失败,原因: %@",*error];
                JDNetLog(@"%@",str);
                [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];
            }
        }
        return NO;
    }

    return YES;
}

/**
 检查缓存是否可用

 @param error NSError
 @return YES/NO
 */
- (BOOL)validateCacheWithError:(NSError * _Nullable __autoreleasing *)error {
    // Date缓存时间检查
    NSDate *creationDate = self.cacheMetadata.creationDate;// 创建时间
    NSTimeInterval duration = -[creationDate timeIntervalSinceNow];// 与当前时间的时间差
    NSString *str = [NSString stringWithFormat:@"*缓存验证===缓存时间差是: %f 秒，实际缓存时间是%ld 秒",duration,(long)[self cacheTimeInSeconds]];
    if ([JDNetworkConfig sharedConfig].logCacheMetaDataEnabled) {
        JDNetLog(@"%@",str);
    }
    [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];
    if (duration < 0 || duration > [self cacheTimeInSeconds]) {
        if (error) {
//            *error = [NSError errorWithDomain:JDRequestCacheErrorDomain code:JDRequestCacheErrorExpired userInfo:@{ NSLocalizedDescriptionKey:@"Cache expired"}];
             *error = [NSError errorWithDomain:JDRequestCacheErrorDomain code:JDRequestCacheErrorExpired userInfo:@{ NSLocalizedDescriptionKey:@"缓存过期了"}];
        }
        return NO;
    }
    // Version
    long long cacheVersionFileContent = self.cacheMetadata.version;
    str = [NSString stringWithFormat:@"*缓存验证===缓存版本: %lld,请求的缓存版本是%lld",cacheVersionFileContent,[self cacheVersion]];
    if ([JDNetworkConfig sharedConfig].logCacheMetaDataEnabled) {
        JDNetLog(@"%@",str);
    }
    [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];
    if (cacheVersionFileContent != [self cacheVersion]) { // 匹配版本
        if (error) {
//            *error = [NSError errorWithDomain:JDRequestCacheErrorDomain code:JDRequestCacheErrorVersionMismatch userInfo:@{ NSLocalizedDescriptionKey:@"Cache version mismatch"}];
             *error = [NSError errorWithDomain:JDRequestCacheErrorDomain code:JDRequestCacheErrorVersionMismatch userInfo:@{ NSLocalizedDescriptionKey:@"缓存版本不匹配"}];
           
        }
        return NO;
    }
    // Sensitive data 特殊数据
    NSString *sensitiveDataString = self.cacheMetadata.sensitiveDataString;
    NSString *currentSensitiveDataString = ((NSObject *)[self cacheSensitiveData]).description;
    str = [NSString stringWithFormat:@"*缓存验证===保存的缓存标识: %@ *当前请求的是:%@",sensitiveDataString,currentSensitiveDataString];
//    JDNetLog(@"%@",str);
    if ([JDNetworkConfig sharedConfig].logCacheMetaDataEnabled) {
        JDNetLog(@"%@",str);
    }
    if (sensitiveDataString || currentSensitiveDataString) {
        // If one of the strings is nil, short-circuit evaluation will trigger
        if (sensitiveDataString.length != currentSensitiveDataString.length || ![sensitiveDataString isEqualToString:currentSensitiveDataString]) {
            if (error) {
//                *error = [NSError errorWithDomain:JDRequestCacheErrorDomain code:JDRequestCacheErrorSensitiveDataMismatch userInfo:@{ NSLocalizedDescriptionKey:@"Cache sensitive data mismatch"}];
                 *error = [NSError errorWithDomain:JDRequestCacheErrorDomain code:JDRequestCacheErrorSensitiveDataMismatch userInfo:@{ NSLocalizedDescriptionKey:@"特殊缓存标识不匹配"}];
            }
            return NO;
        }
    }
    // App version App 版本
    NSString *appVersionString = self.cacheMetadata.appVersionString;
    NSString *currentAppVersionString = [JDNetworkUtils appVersionString];
    str = [NSString stringWithFormat:@"*缓存验证===保存的缓存版本是: %@ *当前请求的是:%@",appVersionString,currentAppVersionString];
    if ([JDNetworkConfig sharedConfig].logCacheMetaDataEnabled) {
        JDNetLog(@"%@",str);
    }
    if (appVersionString || currentAppVersionString) {
        if (appVersionString.length != currentAppVersionString.length || ![appVersionString isEqualToString:currentAppVersionString]) {
            if (error) {
//                *error = [NSError errorWithDomain:JDRequestCacheErrorDomain code:JDRequestCacheErrorAppVersionMismatch userInfo:@{ NSLocalizedDescriptionKey:@"App version mismatch"}];
                  *error = [NSError errorWithDomain:JDRequestCacheErrorDomain code:JDRequestCacheErrorAppVersionMismatch userInfo:@{ NSLocalizedDescriptionKey:@"App 版本不匹配"}];

            }
            return NO;
        }
    }
    return YES;
}

/**
 加载元数据,元数据存储了一些缓存信息

 @return YES/NO
 */
- (BOOL)loadCacheMetadata {
    NSString *path = [self cacheMetadataFilePath];//获取.metadata元数据的路径
    NSFileManager * fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path isDirectory:nil]) {// 如果文件存在
        @try {
            _cacheMetadata = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
            JDNetLog(@"获取的缓存信息是: %@",[_cacheMetadata ecn_getAllPropertyValues]);
            return YES;
        } @catch (NSException *exception) {
//            JDNetLog(@"Load cache metadata failed, reason = %@", exception.reason);
            NSString *str = [NSString stringWithFormat:@"*加载缓存元数据信息失败，原因是: %@", exception.reason];
            JDNetLog(@"%@",str);
            [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];
            return NO;
        }
    }
    return NO;
}

/**
  加载缓存数据，同时返回是否加载成功

 @return YES/NO
 */
- (BOOL)loadCacheData {
    NSString *path = [self cacheFilePath];// 获取缓存路径
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;

    if ([fileManager fileExistsAtPath:path isDirectory:nil]) {// 缓存文件存在
        NSData *data = [NSData dataWithContentsOfFile:path];
        _cacheData = data; // 缓存数据
        _cacheString = [[NSString alloc] initWithData:_cacheData encoding:self.cacheMetadata.stringEncoding];// 进行编码
        switch (self.responseSerializerType) {// 进行序列化
            case JDResponseSerializerTypeHTTP:
                // Do nothing.
                return YES;
            case JDResponseSerializerTypeJSON:
                _cacheJSON = [NSJSONSerialization JSONObjectWithData:_cacheData options:(NSJSONReadingOptions)0 error:&error];
                return error == nil;
            case JDResponseSerializerTypeXMLParser:
                _cacheXML = [[NSXMLParser alloc] initWithData:_cacheData];
                return YES;
        }
    }
    return NO;
}

/**
 保存缓存数据

 @param data NSData
 */
- (void)saveResponseDataToCacheFile:(NSData *)data {
    if ([self cacheTimeInSeconds] > 0 && ![self isDataFromCache]) {
        if (data != nil) {
            @try {
                // New data will always overwrite old data.
                // 新数据总是会覆盖旧数据
                [data writeToFile:[self cacheFilePath] atomically:YES];
                // 记录缓存元数据（缓存信息)
                JDCacheMetadata *metadata = [[JDCacheMetadata alloc] init];
                metadata.version = [self cacheVersion];// 记录缓存版本
                metadata.sensitiveDataString = ((NSObject *)[self cacheSensitiveData]).description;// 特殊标识
                metadata.stringEncoding = [JDNetworkUtils stringEncodingWithRequest:self];// 获取request的编码
                metadata.creationDate = [NSDate date];// 记录当前时间
                metadata.appVersionString = [JDNetworkUtils appVersionString];// 获取APP版本
                // 保存到本地
                [NSKeyedArchiver archiveRootObject:metadata toFile:[self cacheMetadataFilePath]];
            } @catch (NSException *exception) {
//                JDNetLog(@"Save cache failed, reason = %@", exception.reason);
                NSString *str = [NSString stringWithFormat:@"*保存缓存失败，原因是: %@", exception.reason];
                JDNetLog(@"%@",str);
                [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];
            }
        }
    }
}

/**
  清除所有的内存数据
 */
- (void)clearCacheVariables {
    _cacheData = nil;
    _cacheXML = nil;
    _cacheJSON = nil;
    _cacheString = nil;
    _cacheMetadata = nil;
    _dataFromCache = NO;
}

#pragma mark -缓存路径的一些方法

/**
 检查是否需要创建基础缓存目录

 @param path PAth
 */
- (void)createDirectoryIfNeeded:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir;
    if (![fileManager fileExistsAtPath:path isDirectory:&isDir]) {// 不存在就创建
        [self createBaseDirectoryAtPath:path];
    } else {
        if (!isDir) {// 如果不是目录
            NSError *error = nil;
            [fileManager removeItemAtPath:path error:&error];// 移除
            [self createBaseDirectoryAtPath:path];// 根据path创建目录
        }
    }
}

/**
 根据文件路径创建基础路径，path可能会是一个非目录的文件路径

 @param path PATH
 */
- (void)createBaseDirectoryAtPath:(NSString *)path {
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES
                                               attributes:nil error:&error];// 只创建这个path下面的目录
    if (error) {
//        JDNetLog(@"create cache directory failed, error = %@", error);
        NSString *str = [NSString stringWithFormat:@"*创建缓存目录失败，错误是: %@",error];
        JDNetLog(@"%@",str);
        [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];
    } else {
        [JDNetworkUtils addDoNotBackupAttribute:path]; // 设置此缓存路径不进行备份
    }
}

/**
  缓存路径

 @return PATH
 */
- (NSString *)cacheBasePath {
    NSString *pathOfLibrary = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *path = [pathOfLibrary stringByAppendingPathComponent:@"LazyRequestCache"];

    // Filter cache base path
    //给路径添加一些过滤路径
    NSArray<id<JDCacheDirPathFilterProtocol>> *filters = [[JDNetworkConfig sharedConfig] cacheDirPathFilters];
    if (filters.count > 0) {
        for (id<JDCacheDirPathFilterProtocol> f in filters) {
            path = [f filterCacheDirPath:path withRequest:self];// 这个由外部自行实现方法，
        }
    }
    //检查是否需要创建基础缓存目录
    [self createDirectoryIfNeeded:path];
    return path;
}

/**
 缓存文件名

 @return name
 */
- (NSString *)cacheFileName {
    NSString *requestUrl = [self requestUrl];
    NSString *baseUrl = [JDNetworkConfig sharedConfig].baseUrl;
    id argument = [self cacheFileNameFilterForRequestArgument:[self requestArgument]];// 根据设定的参数来缓存，默认是全部参数 也可子类指定
    NSString *requestInfo = [NSString stringWithFormat:@"Method:%ld Host:%@ Url:%@ Argument:%@",
                             (long)[self requestMethod], baseUrl, requestUrl, argument];
    NSString *cacheFileName = [JDNetworkUtils md5StringFromString:requestInfo];
    return cacheFileName;
}

/**
 缓存文件路径

 @return PATH
 */
- (NSString *)cacheFilePath {
    NSString *cacheFileName = [self cacheFileName];
    NSString *path = [self cacheBasePath];
    path = [path stringByAppendingPathComponent:cacheFileName];
    return path;
}

/**
 元数据缓存路径

 @return PATH
 */
- (NSString *)cacheMetadataFilePath {
    NSString *cacheMetadataFileName = [NSString stringWithFormat:@"%@.metadata", [self cacheFileName]];
    NSString *path = [self cacheBasePath];
    path = [path stringByAppendingPathComponent:cacheMetadataFileName];
    return path;
}

@end
