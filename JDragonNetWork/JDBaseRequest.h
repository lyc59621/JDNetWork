//
//  JDBaseRequest.h
//  JDNetWork
//
//  Created by JDragon on 2018/8/25.
//  Copyright © 2018年 JDragon. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const JDRequestValidationErrorDomain;
/** 错误码 */
NS_ENUM(NSInteger) {
    JDRequestValidationErrorInvalidStatusCode = -8,// 返回码不匹配
    JDRequestValidationErrorInvalidJSONFormat = -9,// json字段校验失败
};

///  HTTP Request method.
    
/**
  请求方法

 - JDRequestMethodGET: GET
 - JDRequestMethodPOST: POST
 - JDRequestMethodHEAD: HEAD
 - JDRequestMethodPUT: PUT
 - JDRequestMethodDELETE: DELETE
 - JDRequestMethodPATCH: PATCH
 */
typedef NS_ENUM(NSInteger, JDRequestMethod) {
    JDRequestMethodGET = 0,
    JDRequestMethodPOST,
    JDRequestMethodHEAD,
    JDRequestMethodPUT,
    JDRequestMethodDELETE,
    JDRequestMethodPATCH,
};


/**
 请求序列类型

 - JDRequestSerializerTypeHTTP: HTTP
 - JDRequestSerializerTypeJSON: JSON
 */
typedef NS_ENUM(NSInteger, JDRequestSerializerType) {
    JDRequestSerializerTypeHTTP = 0,
    JDRequestSerializerTypeJSON,
};

    
/**
 返回内容responseObject的格式
 */
typedef NS_ENUM(NSInteger, JDResponseSerializerType) {
    /// NSData type
    JDResponseSerializerTypeHTTP,
    /// JSON object type
    JDResponseSerializerTypeJSON,
    /// NSXMLParser type
    JDResponseSerializerTypeXMLParser,
};
/**
 Request priority 请求优先级

 - JDRequestPriorityLow: Low
 - JDRequestPriorityDefault: Default
 - JDRequestPriorityHigh: High
 */
typedef NS_ENUM(NSInteger, JDRequestPriority) {
    JDRequestPriorityLow = -4L,
    JDRequestPriorityDefault = 0,
    JDRequestPriorityHigh = 4,
};

@protocol AFMultipartFormData;

typedef void (^AFConstructingBlock)(id<AFMultipartFormData> formData);
typedef void (^AFURLSessionTaskProgressBlock)(NSProgress *);

@class JDBaseRequest;

/**
 完成的Block回调

 @param request request
 */
typedef void(^JDRequestCompletionBlock)(__kindof JDBaseRequest *request);


#pragma mark - JDRequestDelegate
/**
 所有的回调是在主线中被回调的
 */
@protocol JDRequestDelegate <NSObject>

@optional
/**
 Tell the delegate that the request has finished successfully. 请求完成

 @param request request
 */
- (void)requestFinished:(__kindof JDBaseRequest *)request;


/**
 Tell the delegate that the request has failed.请求失败

 @param request request
 */
- (void)requestFailed:(__kindof JDBaseRequest *)request;

@end

#pragma mark - JDRequestAccessory

    
/**
 The JDRequestAccessory protocol defines several optional methods that can be
 used to track the status of a request. Objects that conforms this protocol
 ("accessories") can perform additional configurations accordingly. All the
  accessory methods will be called on the main queue.
 其他几种请求状态delegate，在主线程中回调
 */
@protocol JDRequestAccessory <NSObject>

@optional

///  Inform the accessory that the request is about to start.
///  请求将要开始
///  @param request The corresponding request.
- (void)requestWillStart:(id)request;

///  Inform the accessory that the request is about to stop. This method is called
///  before executing `requestFinished` and `successCompletionBlock`.
///  将在requestFinished` 和 `successCompletionBlock回调 `前` 调用
///  @param request The corresponding request.
- (void)requestWillStop:(id)request;

///  Inform the accessory that the request has already stoped. This method is called
///  after executing `requestFinished` and `successCompletionBlock`.
///  将在requestFinished` 和 `successCompletionBlock回调 `后` 调用
///  @param request The corresponding request.
- (void)requestDidStop:(id)request;

@end
    
#pragma mark - JDBaseRequest
/**
 JDBaseRequest is the abstract class of network request. It provides many options
 for constructing request. It's the base class of `JDRequest`.
 业务请求基类，建议项目再继承一层进行统一处理
 */
@interface JDBaseRequest : NSObject

#pragma mark - Request and Response Information
///=============================================================================
/// @name Request and Response Information
///=============================================================================

///  The underlying NSURLSessionTask.
///  请求开始前为nil
///  @warning This value is actually nil and should not be accessed before the request starts.
@property (nonatomic, strong, readonly) NSURLSessionTask *requestTask;
/**
 Shortcut for `requestTask.currentRequest`.
 快速获取 requestTask.currentRequest
 */
@property (nonatomic, strong, readonly) NSURLRequest *currentRequest;

/**
 Shortcut for `requestTask.originalRequest`.
 快速获取 requestTask.originalRequest
 */
@property (nonatomic, strong, readonly) NSURLRequest *originalRequest;

/**
 Shortcut for `requestTask.response`.
 快速获取 requestTask.response
 */
@property (nonatomic, strong, readonly) NSHTTPURLResponse *response;

/**
 The response status code.
  获取返回的状态码
 */
@property (nonatomic, readonly) NSInteger responseStatusCode;

/**
 The response header fields.
 获取请求返回头
 */
@property (nonatomic, strong, readonly, nullable) NSDictionary *responseHeaders;

/**
 The raw data representation of response. Note this value can be nil if request failed.
 请求返回的原数据NSData格式，请求失败时此值为nil
 */
@property (nonatomic, strong, readonly, nullable) NSData *responseData;

/**
 The string representation of response. Note this value can be nil if request failed.
 请求返回的原数据NSString格式，请求失败时此值为nil
 */
@property (nonatomic, strong, readonly, nullable) NSString *responseString;

/**
 This serialized response object. The actual type of this object is determined by
 `JDResponseSerializerType`. Note this value can be nil if request failed.
 
 @discussion If `resumableDownloadPath` and DownloadTask is using, this value will
            be the path to which file is successfully saved (NSURL), or nil if request failed.
 根据ECResponseSerializerType的设置，返回对应格式的内容；
 如果设置了resumableDownloadPath 并且是下载任务，则会返回file的NSURL地址
 */
@property (nonatomic, strong, readonly, nullable) id responseObject;

/**
 If you use `JDResponseSerializerTypeJSON`, this is a convenience (and sematic) getter
 for the response object. Otherwise this value is nil.
 如果是设置的JDResponseSerializerTypeJSON，则直接返回json object ，否则此值为nil
 */
@property (nonatomic, strong, readonly, nullable) id responseJSONObject;

/**
 This error can be either serialization error or network error. If nothing wrong happens
 his value will be nil.
 返回错误，包括网络错误；否则此值为nil
 */
@property (nonatomic, strong, readonly, nullable) NSError *error;

/**
 Return cancelled state of request task.
 返回request task 的isCancelled取消状态
 */
@property (nonatomic, readonly, getter=isCancelled) BOOL cancelled;

/**
 Executing state of request task.
 返回request task 的isExecuting执行状态
 */
@property (nonatomic, readonly, getter=isExecuting) BOOL executing;

#pragma mark - 获取请求url及参数

#pragma mark - Request Configuration 一些请求设置
///=============================================================================
/// @name Request Configuration
///=============================================================================

/**
 Tag can be used to identify request. Default value is 0.
 请求标识，默认是0
 */
@property (nonatomic) NSInteger tag;

/**
 The userInfo can be used to store additional info about the request. Default is nil.
 额外的信息储存，默认是nil
 */
@property (nonatomic, strong, nullable) NSDictionary *userInfo;

/**
 The delegate object of the request. If you choose block style callback you can ignore this.
 Default is nil.
 回调delegate，如果使用block，这里可以忽略
 */
@property (nonatomic, weak, nullable) id<JDRequestDelegate> delegate;

/**
 The success callback. Note if this value is not nil and `requestFinished` delegate method is
 also implemented, both will be executed but delegate method is first called. This block
 will be called on the main queue.
 成功回调，会在主线中回调，但是如果同时设置了delegate，delegate方法会被优先回调
 */
@property (nonatomic, copy, nullable) JDRequestCompletionBlock successCompletionBlock;

/**
 The failure callback. Note if this value is not nil and `requestFailed` delegate method is
 also implemented, both will be executed but delegate method is first called. This block
 will be called on the main queue. 同successCompletionBlock
 */
@property (nonatomic, copy, nullable) JDRequestCompletionBlock failureCompletionBlock;

/**
 This can be used to add several accossories object. Note if you use `addAccessory` to add acceesory
 this array will be automatically created. Default is nil.
 与方法 addAccessory 关联使用，设置状态监控
 */
@property (nonatomic, strong, nullable) NSMutableArray<id<JDRequestAccessory>> *requestAccessories;


#pragma mark - ***文件上传、下载 >start
#pragma mark - 文件上传实现

/**
 This can be use to construct HTTP body when needed in POST request. Default is nil.
 当POST的内容带有文件等富文本时使用
 POST请求时，用于构造HTTP body，返回AFMultipartFormData
 多文件上传时，可以使用以下方法来构造多个文件上传内容
 [formData appendPartWithFileData:data name:name fileName:fileName mimeType:mimeType];
 */
@property (nonatomic, copy, nullable) AFConstructingBlock constructingBodyBlock;

#pragma mark - 文件下载实现
/**
   @discussion NSURLSessionDownloadTask is used when this value is not nil.
               The exist file at the path will be removed before the request starts. If request succeed, file will
               be saved to this path automatically, otherwise the response will be saved to `responseData`
               and `responseString`. For this to work, server must support `Range` and response with
               proper `Last-Modified` and/or `Etag`. See `NSURLSessionDownloadTask` for more detail.
 此值非nil时，将调用NSURLSessionDownloadTask.
 断点下载开始前，如果存在同路径文件，该文件将被删除。请求成功后，文件会被写到此路径。
 断点续传下载，要求服务器支持`Range`并且返回`Last-Modified` and/or `Etag`。详情见NSURLSessionDownloadTask
 */
@property (nonatomic, strong, nullable) NSString *resumableDownloadPath;

/**
 You can use this block to track the download progress. See also `resumableDownloadPath`.
 下载进度回调,操作时请回主线程操作
 */
@property (nonatomic, copy, nullable) AFURLSessionTaskProgressBlock resumableDownloadProgressBlock;

/** 上传进度回调,操作时请回主线程操作 */
@property (nonatomic, copy, nullable) AFURLSessionTaskProgressBlock uploadProgressBlock;


#pragma mark - ***文件上传、下载 >end
/**
 The priority of the request. Effective only on iOS 8+. Default is `JDRequestPriorityDefault`.
 请求优先级，IOS8以上有效，默认JDRequestPriorityDefault
 */
@property (nonatomic) JDRequestPriority requestPriority;

/**
 Set completion callbacks
 设置请求回调

 @param success 成功block回调
 @param failure 失败block回谳
 */
- (void)setCompletionBlockWithSuccess:(nullable JDRequestCompletionBlock)success
                              failure:(nullable JDRequestCompletionBlock)failure;

/**
 Nil out both success and failure callback blocks.
 当请求成功或失败时，会清除block 回调，并设为nil
 */
- (void)clearCompletionBlock;

/**
 Convenience method to add request accessory. See also `requestAccessories`.
 添加request状态跟踪，配合requestAccessories使用*

 @param accessory <#accessory description#>
 */
- (void)addAccessory:(id<JDRequestAccessory>)accessory;


#pragma mark - Request Action 一些请求动作
///=============================================================================
/// @name Request Action
///=============================================================================

/**
 Append self to request queue and start the request.
 将self添加到请求队列，并开始请求
 */
- (void)start;

/**
  Remove self from request queue and cancel the request.
  将self移除请求队列，并停止请求
 */
- (void)stop;

///  Convenience method to start the request with block callbacks.

/**
 直接start开始，否则使用自行start方法.

 @param success 成功block回调
 @param failure 失败block回谳
 */
- (void)startWithCompletionBlockWithSuccess:(nullable JDRequestCompletionBlock)success
                                    failure:(nullable JDRequestCompletionBlock)failure;


#pragma mark - Subclass Override 子类可以重写的方法
///=============================================================================
/// @name Subclass Override
///=============================================================================

/**
 Called on background thread after request succeded but before switching to main thread. Note if
 cache is loaded, this method WILL be called on the main thread, just like `requestCompleteFilter`.
 重写此方法，表示在主线程回调前可以在background thread内做一些事情，
 如果有缓存，此方法会直接在主线程中
 */
- (void)requestCompletePreprocessor;

/**
 Called on the main thread after request succeeded.
 请求成功后，会在主线程内回调
 */
- (void)requestCompleteFilter;

/**
 Called on background thread after request failed but before switching to main thread. See also
 `requestCompletePreprocessor`.
 请求成功后，但是尚未切换到主线程前，进行一些操作。
 同requestCompletePreprocessor
 */
- (void)requestFailedPreprocessor;

/**
 Called on the main thread when request failed.
 请求失败后，会在主线程内回调
 */
- (void)requestFailedFilter;

/**
 The baseURL of request. This should only contain the host part of URL, e.g., http://www.example.com.
 See also `requestUrl`
  业务类可以单独设置baseUrl，不设置时，使用JDNetworkConfig中的设置

 @return baseUrl
 */
- (NSString *)baseUrl;

///  The URL path of request. This should only contain the path part of URL, e.g., /v1/user. See alse `baseUrl`.
///
///  @discussion This will be concated with `baseUrl` using [NSURL URLWithString:relativeToURL].
///              Because of this, it is recommended that the usage should stick to rules stated above.
///              Otherwise the result URL may not be correctly formed. See also `URLString:relativeToURL`
///              for more information.
///
///              Additionaly, if `requestUrl` itself is a valid URL, it will be used as the result URL and
///              `baseUrl` will be ignored.
- (NSString *)requestUrl;

///  Optional CDN URL for request.
- (NSString *)cdnUrl;

/**
 Requset timeout interval. Default is 60s.
 @discussion When using `resumableDownloadPath`(NSURLSessionDownloadTask), the session seems to completely ignore
              `timeoutInterval` property of `NSURLRequest`. One effective way to set timeout would be using
              `timeoutIntervalForResource` of `NSURLSessionConfiguration`.
 请求超时时间
 当使用`resumableDownloadPath`(NSURLSessionDownloadTask)时，貌似不可用。
 可以使用NSURLSessionConfiguration的timeoutIntervalForResource方法
 @return 时间戳返回，默认是15秒，如果有上传时，默认值是60

 @return <#return value description#>
 */
- (NSTimeInterval)requestTimeoutInterval;

///  Additional request argument.
- (nullable id)requestArgument;

/**
 Override this method to filter requests with certain arguments when caching.
 Override this method to filter requests with certain arguments when caching.
 以某些参数来缓存，默认是全参数 requestArgument
 @param argument 参数
 @return chche
 */
- (id)cacheFileNameFilterForRequestArgument:(id)argument;

/**
 HTTP request method.
 返回请求方法

 @return <#return value description#>
 */
- (JDRequestMethod)requestMethod;

/**
 Request serializer type.
 默认 JDRequestSerializerTypeHTTP

 @return <#return value description#>
 */
- (JDRequestSerializerType)requestSerializerType;

/**
  Response serializer type. See also `responseObject`.
  默认 JDResponseSerializerTypeJSON

 @return <#return value description#>
 */
- (JDResponseSerializerType)responseSerializerType;

/**
 Username and password used for HTTP authorization. Should be formed as @[@"Username", @"Password"].
 HTTP的用户名和密码设置，如果有要求的话. 格式是 @[@"Username", @"Password"].

 @return <#return value description#>
 */
- (nullable NSArray<NSString *> *)requestAuthorizationHeaderFieldArray;

/**
 Additional HTTP request header field.
 额外的请求头信息

 @param NSDictionary<NSString <#NSDictionary<NSString description#>
 @param > <#> description#>
 @return <#return value description#>
 */
- (nullable NSDictionary<NSString *, NSString *> *)requestHeaderFieldValueDictionary;
/**
 Use this to build custom request. If this method return non-nil value, `requestUrl`, `requestTimeoutInterval`,
 `requestArgument`, `allowsCellularAccess`, `requestMethod` and `requestSerializerType` will all be ignored.
 自定请求，如果自定了，将忽略以下方法,
 `requestUrl`, `requestTimeoutInterval`,`requestArgument`, `allowsCellularAccess`, `requestMethod` 和 `requestSerializerType`.
 @return 返回自定的NSURLRequest 类型

 @return <#return value description#>
 */
- (nullable NSURLRequest *)buildCustomUrlRequest;

/**
 Should use CDN when sending request.
 是否使用CDN

 @return <#return value description#>
 */
- (BOOL)useCDN;

/**
 Whether the request is allowed to use the cellular radio (if present). Default is YES.
 此业务是否允许使用蜂窝数据请求，NSURLSessionConfiguration .allowsCellularAccess,默认值是YES.

 @return <#return value description#>
 */
- (BOOL)allowsCellularAccess;

/**
  The validator will be used to test if `responseJSONObject` is correctly formed.
  验证 responseJSONObject 的字段格式

 @return <#return value description#>
 */
- (nullable id)jsonValidator;

/**
 This validator will be used to test if `responseStatusCode` is valid.
  测试responseStatusCode

 @return <#return value description#>
 */
- (BOOL)statusCodeValidator;

@end

NS_ASSUME_NONNULL_END
