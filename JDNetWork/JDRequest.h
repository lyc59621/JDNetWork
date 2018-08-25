//
//  JDRequest.h
//  JDNetWork
//
//  Created by JDragon on 2018/8/25.
//  Copyright © 2018年 JDragon. All rights reserved.
//

#import "JDBaseRequest.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const JDRequestCacheErrorDomain;

NS_ENUM(NSInteger) {
    JDRequestCacheErrorExpired = -1,// 过期
    JDRequestCacheErrorVersionMismatch = -2,// 缓存版本不匹配
    JDRequestCacheErrorSensitiveDataMismatch = -3,// 特殊缓存标识不匹配
    JDRequestCacheErrorAppVersionMismatch = -4, // APP版本不匹配
    JDRequestCacheErrorInvalidCacheTime = -5, // 缓存时间不可用
    JDRequestCacheErrorInvalidMetadata = -6,// 元数据(缓存信息)错误
    JDRequestCacheErrorInvalidCacheData = -7,
};


    
/**
 JDRequest is the base class you should inherit to create your own request class.
 Based on JDBaseRequest, JDRequest adds local caching feature. Note download
 request will not be cached whatsoever, because download request may involve complicated
 cache control policy controlled by `Cache-Control`, `Last-Modified`, etc.
 JDRequest 基于 JDBaseRequest提供了一些缓存方法；
 当前项目需要创建业务请求时，继承此类。
 此类提供的缓存方案并不支撑下载请求，因为下载请求可能涉及复杂的缓存控制机制，如`Cache-Control`, `Last-Modified`
*/
@interface JDRequest : JDBaseRequest

/**
 Whether to use cache as response or not.
 Default is NO, which means caching will take effect with specific arguments.
 Note that `cacheTimeInSeconds` default is -1. As a result cache data is not actually
 used as response unless you return a positive value in `cacheTimeInSeconds`.
 
 Also note that this option does not affect storing the response, which means response will always be saved
 even `ignoreCache` is YES.
 忽略缓存，默认值是NO；
 此方法并不影响请求返回的存储方法；
 cacheTimeInSeconds 默认是-1，需要设置一个有效的时间，才可以开启缓存
 */
@property (nonatomic) BOOL ignoreCache;

/**
 数据是否来自缓存   Whether data is from local cache.

 @return YES/No
 */
- (BOOL)isDataFromCache;

/**
 加载缓存数据                                    Manually load cache from storage.

 @param error 如果加载有错误时，将返回错误内容       error If an error occurred causing cache loading failed, an error object will be passed, otherwise NULL.
 @return 返回是否加载成功                         Whether cache is successfully loaded.
 */
- (BOOL)loadCacheWithError:(NSError * __autoreleasing *)error;

/**
 Start request without reading local cache even if it exists. Use this to update local cache.
 不使用缓存，直接请求。新返回的数据会更新本地缓存
 */
- (void)startWithoutCache;

/**
 Save response data (probably from another request) to this request's cache location
 保存数据（可能是其他请求来的）到这个请求的缓存位置

 @param data NSData
 */
- (void)saveResponseDataToCacheFile:(NSData *)data;

#pragma mark - Subclass Override  子类重写

/**
 The max time duration that cache can stay in disk until it's considered expired.
 Default is -1, which means response is not actually saved as cache.
 物理缓存最大有效时间
 默认值是-1，表示不会保存缓存

 @return <#return value description#>
 */
- (NSInteger)cacheTimeInSeconds;

/**
 Version can be used to identify and invalidate local cache. Default is 0.
 用于验证本地缓存的版本标识，默认是0；
 缓存版本不一样时，会导致失败 。

 @return long long
 */
- (long long)cacheVersion;

/**
 This can be used as additional identifier that tells the cache needs updating.
 @discussion The `description` string of this object will be used as an identifier to verify whether cache
             is invalid. Using `NSArray` or `NSDictionary` as return value type is recommended. However,
             If you intend to use your custom class type, make sure that `description` is correctly implemented.
 返回一个特殊标识，可以告诉缓存需要更新；
 建议返回类型是 `NSArray` 或 `NSDictionary` ；
 如果需要特定类型，必须保证它的 `description`是正确的描述
 */
- (nullable id)cacheSensitiveData;

/**
 Whether cache is asynchronously written to storage. Default is YES.
 是否异步写缓存，默认值是YES

 @return YES/NO
 */
- (BOOL)writeCacheAsynchronously;

@end

NS_ASSUME_NONNULL_END
