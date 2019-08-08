//
//  JDNetworkConfig.h
//  JDNetWork
//
//  Created by JDragon on 2018/8/25.
//  Copyright © 2018年 JDragon. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class JDBaseRequest;
@class AFSecurityPolicy;

/** 接收调试通知，可以在开发选项中接收一些log信息 */
static NSString *const JDNetworkDebugLogNotification = @"com.JDragon.network.debug.log.notic";

#pragma mark - JDUrlFilterProtocol

/**
  用于在请求前添加一些公共参
  JDUrlFilterProtocol can be used to append common parameters to requests before sending them.
 */
@protocol JDUrlFilterProtocol <NSObject>


/**
 请求前组装request URL                              Preprocess request URL before actually sending them.

 @param originUrl 原URL,也就是`requestUrl`         originUrl request's origin URL, which is returned by `requestUrl`
 @param request 本身                              param request   request itself
 @return 返回一个新的`requestUrl`                   return A new url which will be used as a new `requestUrl`
 */
- (NSString *)filterUrl:(NSString *)originUrl withRequest:(JDBaseRequest *)request;
@end

/**
 JDCacheDirPathFilterProtocol can be used to append common path components when caching response results
 在缓存返回数据时，添加一些公共参
 */
@protocol JDCacheDirPathFilterProtocol <NSObject>

/**
 重组缓存path  Preprocess cache path before actually saving them.

 @param originPath  在'JDRequest`中产生的缓存path     originPath original base cache path, which is generated in `JDRequest` class.
 @param request request请求本身                      request itself
 @return 返回新的path                                return A new path which will be used as base path when caching.
 */
- (NSString *)filterCacheDirPath:(NSString *)originPath withRequest:(JDBaseRequest *)request;
@end

/**
 JDNetworkConfig stored global network-related configurations, which will be used in `JDNetworkAgent`
 to form and filter requests, as well as caching response.
 网络请求配置
 */
@interface JDNetworkConfig : NSObject


/**
 设置以下两个方法不可用

 @return <#return value description#>
 */
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 Return a shared config object.
 请求单例，唯一初始化方法；
 @return 返回自身单例
 */
+ (JDNetworkConfig *)sharedConfig;

/**
 Request base URL, such as "http://www.yuantiku.com". Default is empty string.
 基础请求URL，默认是正服Url
 */
@property (nonatomic, strong) NSString *baseUrl;
/**
 Request CDN URL. Default is empty string.
 CDN请求地址
 */
@property (nonatomic, strong) NSString *cdnUrl;



/** 是否发送 JDNetworkDebugLogNotification log通知，默认是NO*/
@property (nonatomic, assign) BOOL developerLogEnabled;
/**
 Whether to log debug info. Default is NO;
 总开关，是否启用debug log，默认是NO ,开启时默认只打印基础请求信息，更多信息需通过其他开关打开
 */
@property (nonatomic, assign) BOOL debugLogEnabled;

/**
  打印返回的原始数据[super responseString]，默认是NO
 */
@property (nonatomic, assign) BOOL logResponseStringEnabled;
/**
 打印返回的序列化数据[super responseObject]，默认是NO
 */
@property (nonatomic, assign) BOOL logResponseObjectEnabled;
/**
 打印缓存数据信息，默认是NO，此开关将在获取及验证缓存信息时，打印缓存/验证信息
 */
@property (nonatomic, assign) BOOL logCacheMetaDataEnabled;
/**
 打印请求/返回头数据处理，默认是NO
 */
@property (nonatomic, assign) BOOL logHeaderInfoEnabled;
/**
 打印请求/返回时的Cookie信息，默认是NO
 */
@property (nonatomic, assign) BOOL logCookieEnabled;

/**
 打印restful处理信息，默认是NO
 */
@property (nonatomic, assign) BOOL logRestfulEnabled;


#pragma mark - 公共参设置项
/**
 url 公共参数
 URL filters. See also `JDUrlFilterProtocol`.
 */
@property (nonatomic, strong, readonly) NSArray<id<JDUrlFilterProtocol>> *urlFilters;
/**
 Cache path filters. See also `JDCacheDirPathFilterProtocol`.
 缓存路径公共参
 */
@property (nonatomic, strong, readonly) NSArray<id<JDCacheDirPathFilterProtocol>> *cacheDirPathFilters;
/**
 Security policy will be used by AFNetworking. See also `AFSecurityPolicy`.
 安全策略设置，默认值是nil,
 关于多域的SSL证书设置，建议使用AFSecurityPolicy的自动查找设置
 */
@property (nonatomic, strong) AFSecurityPolicy *securityPolicy;


/**
 SessionConfiguration will be used to initialize AFHTTPSessionManager. Default is nil.
 在AFHTTPSessionManager初始化时使用，默认是nil
 */
@property (nonatomic, strong) NSURLSessionConfiguration* sessionConfiguration;

/**
 添加一个新公共参

 @param filter <#filter description#>
 */
- (void)addUrlFilter:(id<JDUrlFilterProtocol>)filter;
/**
 Remove all URL filters.
 清除公共参
 */
- (void)clearUrlFilter;
/**
 Add a new cache path filter
 添加缓存路径公共参

 @param filter <#filter description#>
 */
- (void)addCacheDirPathFilter:(id<JDCacheDirPathFilterProtocol>)filter;
/**
 Clear all cache path filters.
 清除缓存路径公共参
 */
- (void)clearCacheDirPathFilter;

@end

NS_ASSUME_NONNULL_END
