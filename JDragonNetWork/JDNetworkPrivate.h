//
//  JDNetworkPrivate.h
//  JDNetWork
//
//  Created by JDragon on 2018/8/25.
//  Copyright © 2018年 JDragon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JDRequest.h"
#import "JDBaseRequest.h"
#import "JDBatchRequest.h"
#import "JDChainRequest.h"
#import "JDNetworkAgent.h"
#import "JDNetworkConfig.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT void JDNetLog(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);

@class AFHTTPSessionManager;

#pragma mark - NSObject
@interface NSObject (get_property)
/**
 获取对象的所有属性 以及属性值

 @return NSDictionary
 */
- (NSDictionary *)ecn_getAllPropertyValues;

@end


#pragma mark - JDNetworkUtils
@interface JDNetworkUtils : NSObject


/**
  json验证，block只有当失败时才有返回

 @param json json
 @param jsonValidator jsonValidator
 @return YES/NO
 */
+ (BOOL)validateJSON:(id)json withValidator:(id)jsonValidator failedJsonBlock:(void(^)(NSDictionary *failedData))block;
/**
 设置这个路径下面的内容不要进行系统备份

 @param path Path
 */
+ (void)addDoNotBackupAttribute:(NSString *)path;

/**
 MD5加密

 @param string string
 @return string
 */
+ (NSString *)md5StringFromString:(NSString *)string;

/**
 获取APP版本 CFBundleShortVersionString

 @return String
 */
+ (NSString *)appVersionString;

/**
 获取request的编码

 @param request JDBaseRequest
 @return NSStringEncoding
 */
+ (NSStringEncoding)stringEncodingWithRequest:(JDBaseRequest *)request;

/**
 断下载的一些数据是否可用

 @param data NSDate
 @return YES/NO
 */
+ (BOOL)validateResumeData:(NSData *)data;

/**
 发送日志通知

 @param userInfo userInfo
 @param object NSObject
 */
+ (void)sendDebugLogNotification:(id)userInfo fromClass:(nullable NSObject *)object;

///

/**
  删除一个串中，除大小写字母、数字、下划线以外的其他字符

 @param string String
 @return String
 */
+ (NSString *)regularStringByLetter_number:(NSString *)string;

/**
 将unicodejson串转成utf-8

 @param unicodeStr String
 @return String
 */
+ (NSString *)translateUnicodeString:(NSString *)unicodeStr;
@end

@interface JDRequest (Getter)

/**
 缓存的基础路径

 @return Path
 */
- (NSString *)cacheBasePath;

@end
#pragma mark - JDBaseRequest Category
@interface JDBaseRequest (Setter)

@property (nonatomic, strong, readwrite) NSURLSessionTask *requestTask;
@property (nonatomic, strong, readwrite, nullable) NSData *responseData;
@property (nonatomic, strong, readwrite, nullable) id responseJSONObject;
@property (nonatomic, strong, readwrite, nullable) id responseObject;
@property (nonatomic, strong, readwrite, nullable) NSString *responseString;
@property (nonatomic, strong, readwrite, nullable) NSError *error;

@end

#pragma mark - JDBaseRequest Category

@interface JDBaseRequest (RequestAccessory)
/**
 统一处理requestWillStart回调
 */
- (void)toggleAccessoriesWillStartCallBack;
/**
 统一处理requestWillStop回调
 */
- (void)toggleAccessoriesWillStopCallBack;
/**
 统一处理requestDidStop回调
 */
- (void)toggleAccessoriesDidStopCallBack;

@end


#pragma mark - JDBatchRequest Category

@interface JDBatchRequest (RequestAccessory)

/**
  统一处理requestWillStart回调
 */
- (void)toggleAccessoriesWillStartCallBack;

/**
  统一处理requestWillStop回调
 */
- (void)toggleAccessoriesWillStopCallBack;
/**
 统一处理requestDidStop回调
 */
- (void)toggleAccessoriesDidStopCallBack;

@end
#pragma mark - JDChainRequest Category
@interface JDChainRequest (RequestAccessory)


/**
 统一处理requestWillStart回调
 */
- (void)toggleAccessoriesWillStartCallBack;

/**
 统一处理requestWillStop回调
 */
- (void)toggleAccessoriesWillStopCallBack;

/**
  统一处理requestDidStop回调
 */
- (void)toggleAccessoriesDidStopCallBack;

@end

@interface JDNetworkAgent (Private)

/**
 获取AFHTTPSessionManager

 @return AFHTTPSessionManager
 */
- (AFHTTPSessionManager *)manager;

/**
 重置AFHTTPSessionManager
 */
- (void)resetURLSessionManager;

/**
 重置AFHTTPSessionManager with configuration

 @param configuration NSURLSessionConfiguration
 */
- (void)resetURLSessionManagerWithConfiguration:(NSURLSessionConfiguration *)configuration;

/**
 临时下载的缓存路径

 @return Path
 */
- (NSString *)incompleteDownloadTempCacheFolder;

@end

NS_ASSUME_NONNULL_END

