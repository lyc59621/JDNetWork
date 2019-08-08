//
//  JDNetworkAgent.m
//  JDNetWork
//
//  Created by JDragon on 2018/8/25.
//  Copyright © 2018年 JDragon. All rights reserved.
//

#import "JDNetworkAgent.h"
#import "JDNetworkConfig.h"
#import "JDNetworkPrivate.h"
#import <pthread/pthread.h>

#if __has_include(<AFNetworking/AFNetworking.h>)
#import <AFNetworking/AFNetworking.h>
#else
#import "AFNetworking.h"
#endif

#define Lock() pthread_mutex_lock(&_lock) //锁定互斥锁,调用该线程将阻塞，直到该互斥锁变为可用为止
#define Unlock() pthread_mutex_unlock(&_lock) // 解锁互斥锁
// 下载时的临时目录
#define kJDNetworkIncompleteDownloadFolderName @"Incomplete"

@implementation JDNetworkAgent {
    AFHTTPSessionManager *_manager;
    JDNetworkConfig *_config;
    AFJSONResponseSerializer *_jsonResponseSerializer;
    AFXMLParserResponseSerializer *_xmlParserResponseSerialzier;
    NSMutableDictionary<NSNumber *, JDBaseRequest *> *_requestsRecord;

    dispatch_queue_t _processingQueue;
    pthread_mutex_t _lock; // 互斥锁
    NSIndexSet *_allStatusCodes;
}

+ (JDNetworkAgent *)sharedAgent {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _config = [JDNetworkConfig sharedConfig];
        _manager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:_config.sessionConfiguration];
        _requestsRecord = [NSMutableDictionary dictionary];// 请求记录
        _processingQueue = dispatch_queue_create("com.yuantiku.networkagent.processing", DISPATCH_QUEUE_CONCURRENT);// 创建进程队列
        _allStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(100, 500)];// 状态码
        pthread_mutex_init(&_lock, NULL);// 使用默认初始化互斥锁

        _manager.securityPolicy = _config.securityPolicy;
        _manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        // Take over the status code validation
        _manager.responseSerializer.acceptableStatusCodes = _allStatusCodes;
        _manager.completionQueue = _processingQueue;
    }
    return self;
}

- (AFJSONResponseSerializer *)jsonResponseSerializer {
    if (!_jsonResponseSerializer) {
        _jsonResponseSerializer = [AFJSONResponseSerializer serializer];
        _jsonResponseSerializer.acceptableStatusCodes = _allStatusCodes;

    }
    return _jsonResponseSerializer;
}

- (AFXMLParserResponseSerializer *)xmlParserResponseSerialzier {
    if (!_xmlParserResponseSerialzier) {
        _xmlParserResponseSerialzier = [AFXMLParserResponseSerializer serializer];
        _xmlParserResponseSerialzier.acceptableStatusCodes = _allStatusCodes;
    }
    return _xmlParserResponseSerialzier;
}

#pragma mark -

/**
 根据request 进行url重建

 @param request request
 @return url
 */
- (NSString *)buildRequestUrl:(JDBaseRequest *)request {
    NSParameterAssert(request != nil); // 当request==nil时,异常抛出

    NSString *detailUrl = [request requestUrl]; // 根据JDBaseRequest *request 的业务配置来获取URL
    NSURL *temp = [NSURL URLWithString:detailUrl];
    // If detailUrl is valid URL
    if (temp && temp.host && temp.scheme) { // 如果配置了url,直接返回, temp.scheme: http；temp.host:www.epet.com；
        return detailUrl;
    }
    // Filter URL if needed
    NSArray *filters = [_config urlFilters]; // 公共参
    for (id<JDUrlFilterProtocol> f in filters) {
        detailUrl = [f filterUrl:detailUrl withRequest:request];// 重新组装url，如果需要
    }

    NSString *baseUrl;
    if ([request useCDN]) {// 先判断有无CDN
        if ([request cdnUrl].length > 0) {
            baseUrl = [request cdnUrl];
        } else {
            baseUrl = [_config cdnUrl];
        }
    } else {// 否则使用host url
        if ([request baseUrl].length > 0) {
            baseUrl = [request baseUrl];
        } else {
            baseUrl = [_config baseUrl];
        }
    }
    // URL slash compability 拼"/"
    NSURL *url = [NSURL URLWithString:baseUrl];

    if (baseUrl.length > 0 && ![baseUrl hasSuffix:@"/"]) {
        url = [url URLByAppendingPathComponent:@""];
    }
   // 得到url-> https://api.xxx.com/
    return [NSURL URLWithString:detailUrl relativeToURL:url].absoluteString;
}

/**
 根据request完成请求序列相关设置

 @param request request
 @return AFHTTPRequestSerializer
 */
- (AFHTTPRequestSerializer *)requestSerializerForRequest:(JDBaseRequest *)request {
    AFHTTPRequestSerializer *requestSerializer = nil;
    if (request.requestSerializerType == JDRequestSerializerTypeHTTP) {
        requestSerializer = [AFHTTPRequestSerializer serializer];
    } else if (request.requestSerializerType == JDRequestSerializerTypeJSON) {
        requestSerializer = [AFJSONRequestSerializer serializer];
    }

    requestSerializer.timeoutInterval = [request requestTimeoutInterval]; // 超时时间
    requestSerializer.allowsCellularAccess = [request allowsCellularAccess]; // 是否使用蜂窝数据

    // If api needs server username and password
    NSArray<NSString *> *authorizationHeaderFieldArray = [request requestAuthorizationHeaderFieldArray];
    if (authorizationHeaderFieldArray != nil) {
        [requestSerializer setAuthorizationHeaderFieldWithUsername:authorizationHeaderFieldArray.firstObject
                                                          password:authorizationHeaderFieldArray.lastObject];
    }
    NSString *str = [NSString stringWithFormat:@"*处理前的header是: %@",requestSerializer.HTTPRequestHeaders];
    if ([JDNetworkConfig sharedConfig].logHeaderInfoEnabled) {
        JDNetLog(@"%@",str);
    }
    [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];
    // If api needs to add custom value to HTTPHeaderField
    // 如果api需要一设置一些自定义请求头
    NSDictionary<NSString *, NSString *> *headerFieldValueDictionary = [request requestHeaderFieldValueDictionary];
    if (headerFieldValueDictionary != nil) {
        for (NSString *httpHeaderField in headerFieldValueDictionary.allKeys) {
            NSString *value = headerFieldValueDictionary[httpHeaderField];
            [requestSerializer setValue:value forHTTPHeaderField:httpHeaderField];
        }
    }
    return requestSerializer;
}

/**
  request的统一task构建入口

 @param request request
 @param error error
 @return NSURLSessionTask
 */
- (NSURLSessionTask *)sessionTaskForRequest:(JDBaseRequest *)request error:(NSError * _Nullable __autoreleasing *)error {
    JDRequestMethod method = [request requestMethod];// 获取请求方法
    NSString *url = [self buildRequestUrl:request];  // 构建请求URL
    id param = request.requestArgument;
    AFConstructingBlock constructingBlock = [request constructingBodyBlock];
    AFHTTPRequestSerializer *requestSerializer = [self requestSerializerForRequest:request];
//    NSLog(@"网络请求URL:[%@]",url);
//    NSLog(@"网络请求参数:%@",param);
//    NSLog(@"网络请求类型:%@",[self showRequtestMethod:method]);
//    NSLog(@"当前头部信息：[%@]",requestSerializer.HTTPRequestHeaders);
//    NSString *str = [NSString stringWithFormat:@"*处理前的header是: %@",requestSerializer.HTTPRequestHeaders];
//    if ([JDNetworkConfig sharedConfig].logHeaderInfoEnabled) {
//        JDNetLog(@"%@",str);
//    }
//    [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];

    
    switch (method) {
        case JDRequestMethodGET:
            if (request.resumableDownloadPath) {// 如果有下载，则进入下载通道
                return [self downloadTaskWithDownloadPath:request.resumableDownloadPath requestSerializer:requestSerializer URLString:url parameters:param progress:request.resumableDownloadProgressBlock error:error];
            } else {// 否则就是get
                return [self dataTaskWithHTTPMethod:@"GET" requestSerializer:requestSerializer URLString:url parameters:param error:error];
            }
        case JDRequestMethodPOST:// POST
//            return [self dataTaskWithHTTPMethod:@"POST" requestSerializer:requestSerializer URLString:url parameters:param co
//        nstructingBodyWithBlock:constructingBlock error:error];
      return [self dataTaskWithHTTPMethod:@"POST" requestSerializer:requestSerializer URLString:url parameters:param progress:request.uploadProgressBlock constructingBodyWithBlock:constructingBlock error:error];

        case JDRequestMethodHEAD:
            return [self dataTaskWithHTTPMethod:@"HEAD" requestSerializer:requestSerializer URLString:url parameters:param error:error];
        case JDRequestMethodPUT:
            return [self dataTaskWithHTTPMethod:@"PUT" requestSerializer:requestSerializer URLString:url parameters:param error:error];
        case JDRequestMethodDELETE:
            return [self dataTaskWithHTTPMethod:@"DELETE" requestSerializer:requestSerializer URLString:url parameters:param error:error];
        case JDRequestMethodPATCH:
            return [self dataTaskWithHTTPMethod:@"PATCH" requestSerializer:requestSerializer URLString:url parameters:param error:error];
    }
}

- (void)addRequest:(JDBaseRequest *)request {
    NSParameterAssert(request != nil);

    NSError * __autoreleasing requestSerializationError = nil;

    NSURLRequest *customUrlRequest= [request buildCustomUrlRequest];
    if (customUrlRequest) {// 如果是自定请求
        __block NSURLSessionDataTask *dataTask = nil;
        dataTask = [_manager dataTaskWithRequest:customUrlRequest completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
            [self handleRequestResult:dataTask responseObject:responseObject error:error];
        }];
        request.requestTask = dataTask;
    } else {// 正常请求构建
        request.requestTask = [self sessionTaskForRequest:request error:&requestSerializationError];
    }

    if (requestSerializationError) {// 任务构建失败了，就返回失败
        [self requestDidFailWithRequest:request error:requestSerializationError];
        return;
    }
   // requestTask为nil时抛出
    NSAssert(request.requestTask != nil, @"requestTask should not be nil");

    // Set request task priority  设置请求任务的优先级
    // !!Available on iOS 8 +      ios8以上才有效
    if ([request.requestTask respondsToSelector:@selector(priority)]) {// 如果有优先级，就设置task的优先级
        switch (request.requestPriority) {
            case JDRequestPriorityHigh:
                request.requestTask.priority = NSURLSessionTaskPriorityHigh;
                break;
            case JDRequestPriorityLow:
                request.requestTask.priority = NSURLSessionTaskPriorityLow;
                break;
            case JDRequestPriorityDefault:
                /*!!fall through*/
            default:
                request.requestTask.priority = NSURLSessionTaskPriorityDefault;
                break;
        }
    }

    JDNetLog(@"========添加请求: %@ =====", NSStringFromClass([request class]));
    [JDNetworkUtils sendDebugLogNotification:@{@"log":[NSString stringWithFormat:@"*添加请求: %@",NSStringFromClass([request class])]} fromClass:self];
    
    JDNetLog(@"请求地址是: %@",request.currentRequest.URL);
    [JDNetworkUtils sendDebugLogNotification:@{@"log":[NSString stringWithFormat:@"*请求地址是: %@",request.currentRequest.URL]} fromClass:self];
    
    if ([JDNetworkConfig sharedConfig].logCookieEnabled) {
        JDNetLog(@"发起时的cookies是: %@",[NSHTTPCookieStorage sharedHTTPCookieStorage].cookies);
    }
    [JDNetworkUtils sendDebugLogNotification:@{@"log":[NSString stringWithFormat:@"*发起时的cookies是: %@",[NSHTTPCookieStorage sharedHTTPCookieStorage].cookies]} fromClass:self];
    
    // Retain request
    JDNetLog(@"Add request: %@", NSStringFromClass([request class]));
    [self addRequestToRecord:request];// 本地记录数据
    [request.requestTask resume]; // 启动
}

- (void)cancelRequest:(JDBaseRequest *)request {
    NSParameterAssert(request != nil);// 异常抛出request

    if (request.resumableDownloadPath) {
        NSURLSessionDownloadTask *requestTask = (NSURLSessionDownloadTask *)request.requestTask;
        [requestTask cancelByProducingResumeData:^(NSData *resumeData) {
            NSURL *localUrl = [self incompleteDownloadTempPathForDownloadPath:request.resumableDownloadPath];
            [resumeData writeToURL:localUrl atomically:YES];
        }];
    } else {
        [request.requestTask cancel];// 取消请求
    }

    [self removeRequestFromRecord:request];// 移除本地记录
    [request clearCompletionBlock]; // 清除block
}

- (void)cancelAllRequests {
    Lock();// 锁定，保证获取的内容
    NSArray *allKeys = [_requestsRecord allKeys];
    Unlock();
    if (allKeys && allKeys.count > 0) {
        NSArray *copiedKeys = [allKeys copy];
        for (NSNumber *key in copiedKeys) {
            Lock();
            JDBaseRequest *request = _requestsRecord[key];
            Unlock();
            // We are using non-recursive lock.
            // Do not lock `stop`, otherwise deadlock may occur.
            [request stop];
        }
    }
}

/**
 对json格式进行校验

 @param request request
 @param error error
 @return YES/NO
 */
- (BOOL)validateResult:(JDBaseRequest *)request error:(NSError * _Nullable __autoreleasing *)error {
    BOOL result = [request statusCodeValidator];
    if (!result) {
        if (error) {
//            *error = [NSError errorWithDomain:JDRequestValidationErrorDomain code:JDRequestValidationErrorInvalidStatusCode userInfo:@{NSLocalizedDescriptionKey:@"Invalid status code"}];
             *error = [NSError errorWithDomain:JDRequestValidationErrorDomain code:JDRequestValidationErrorInvalidStatusCode userInfo:@{NSLocalizedDescriptionKey:@"不可用的状态码"}];
        }
        return result;
    }
    id json = [request responseJSONObject];
    id validator = [request jsonValidator];
    if (json && validator) {// 如果是json，就进行json序列
        __block NSDictionary *failedInfo = nil;

        //        result = [JDNetworkUtils validateJSON:json withValidator:validator failedJsonBlock:nil];
        result = [JDNetworkUtils validateJSON:json withValidator:validator failedJsonBlock:^(NSDictionary * _Nonnull failedData) {
            failedInfo = failedData;
        }];
        if (!result) {
//            if (error) {
//                *error = [NSError errorWithDomain:JDRequestValidationErrorDomain code:JDRequestValidationErrorInvalidJSONFormat userInfo:@{NSLocalizedDescriptionKey:@"Invalid JSON format"}];
//            }
            if (error) {
                NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:failedInfo];
                [userInfo setObject:request forKey:@"failed_request"];
                [userInfo setObject:@"json字段校验失败" forKey:@"failed_error"];
                *error = [NSError errorWithDomain:JDRequestValidationErrorDomain code:JDRequestValidationErrorInvalidJSONFormat userInfo:userInfo];
                NSString *str = [NSString stringWithFormat:@"*请求: %@ \njson字段校验失败,校验信息是: %@",request,userInfo];
                [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];
            }
            return result;
        }
    }
    return YES;
}

/**
  统一处理回调的地址

 @param task NSURLSessionTask
 @param responseObject ID
 @param error NSError
 */
- (void)handleRequestResult:(NSURLSessionTask *)task responseObject:(id)responseObject error:(NSError *)error {
    Lock();
    JDBaseRequest *request = _requestsRecord[@(task.taskIdentifier)];
    Unlock();

    // When the request is cancelled and removed from records, the underlying
    // AFNetworking failure callback will still kicks in, resulting in a nil `request`.
    //
    // Here we choose to completely ignore cancelled tasks. Neither success or failure
    // callback will be called.
    // 不管请求是取消还是被移除，AFNetworking在底层的失败回调还是会进来这里，request是nil
    // 这里忽略被取消的请求回调。只有成功和失败的才会进行处理
    if (!request) {// 取消/移除的不作处理
        return;
    }

    JDNetLog(@"请求完成的request: %@", NSStringFromClass([request class]));
    [JDNetworkUtils sendDebugLogNotification:@{@"log":[NSString stringWithFormat:@"请求完成的request: %@", NSStringFromClass([request class])]} fromClass:self];
    if ([JDNetworkConfig sharedConfig].logHeaderInfoEnabled) {
        JDNetLog(@"请求返回头信息是: %@",request.responseHeaders);
    }
    [JDNetworkUtils sendDebugLogNotification:@{@"log":[NSString stringWithFormat:@"请求返回头信息是: %@",request.responseHeaders]} fromClass:self];
    
    if ([JDNetworkConfig sharedConfig].logCookieEnabled) {
        JDNetLog(@"请求返回时的cookies是: %@",[NSHTTPCookieStorage sharedHTTPCookieStorage].cookies);
    }
    [JDNetworkUtils sendDebugLogNotification:@{@"log":[NSString stringWithFormat:@"请求返回时的cookies是: %@",[NSHTTPCookieStorage sharedHTTPCookieStorage].cookies]} fromClass:self];
    NSError * __autoreleasing serializationError = nil;
    NSError * __autoreleasing validationError = nil;

    NSError *requestError = nil;
    BOOL succeed = NO;

    request.responseObject = responseObject;
    if ([request.responseObject isKindOfClass:[NSData class]]) {
        request.responseData = responseObject;
        request.responseString = [[NSString alloc] initWithData:responseObject encoding:[JDNetworkUtils stringEncodingWithRequest:request]];

        switch (request.responseSerializerType) {
            case JDResponseSerializerTypeHTTP:
                // Default serializer. Do nothing.
                break;
            case JDResponseSerializerTypeJSON:// 进行json序列解析
                request.responseObject = [self.jsonResponseSerializer responseObjectForResponse:task.response data:request.responseData error:&serializationError];
                request.responseJSONObject = request.responseObject;
                break;
            case JDResponseSerializerTypeXMLParser:// 进行xml序列解析
                request.responseObject = [self.xmlParserResponseSerialzier responseObjectForResponse:task.response data:request.responseData error:&serializationError];
                break;
        }
        if ([JDNetworkConfig sharedConfig].logResponseStringEnabled) {
            NSString *log_str = [JDNetworkUtils translateUnicodeString:request.responseString];
            if (log_str.length <=0) {
                log_str = request.responseString;
            }
            JDNetLog(@"请求: %@ \n返回原始数据是: %@",request,log_str);
        }
        
        if ([JDNetworkConfig sharedConfig].logResponseObjectEnabled) {
            
            NSString *log_str = [JDNetworkUtils translateUnicodeString:[NSString stringWithFormat:@"%@",request.responseObject]];
            if (log_str.length <=0) {
                log_str = request.responseString;
            }
            JDNetLog(@"请求: %@ \n返回序列后的数据是: %@",request,log_str);
        }
        [JDNetworkUtils sendDebugLogNotification:@{@"log":[NSString stringWithFormat:@"请求: %@ \n返回的数据是: %@",request,request.responseString]} fromClass:self];
    }
    if (error) { // 请求失败
        succeed = NO;
        requestError = error;
    } else if (serializationError) { // 格式序列化失败
        succeed = NO;
        requestError = serializationError;
    } else {// json格式校验失败
        succeed = [self validateResult:request error:&validationError];
        requestError = validationError;
    }

    if (succeed) {
        [self requestDidSucceedWithRequest:request];
    } else {
        [self requestDidFailWithRequest:request error:requestError];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self removeRequestFromRecord:request]; // 移除记录
        [request clearCompletionBlock];// 清除block;
    });
}

/**
 请求成功的回调处理

 @param request JDBaseRequest
 */
- (void)requestDidSucceedWithRequest:(JDBaseRequest *)request {
    @autoreleasepool {
        [request requestCompletePreprocessor];
        JDNetLog(@"进入后台线程方法: requestCompletePreprocessor");
         [JDNetworkUtils sendDebugLogNotification:@{@"log":[NSString stringWithFormat:@"进入后台线程方法: requestCompletePreprocessor"]} fromClass:self];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [request toggleAccessoriesWillStopCallBack];// 回调JDRequestAccessory - requestWillStop
        [request requestCompleteFilter];// 子类继承重写可以进行一些处理

        if (request.delegate != nil) {// 先回调delegate
            [request.delegate requestFinished:request];
        }
        if (request.successCompletionBlock) {// 再回调block
            request.successCompletionBlock(request);
        }
        [request toggleAccessoriesDidStopCallBack];// 回调JDRequestAccessory - requestDidStop
    });
}

/**
  请求失败的回调处理

 @param request JDBaseRequest
 @param error NSError
 */
- (void)requestDidFailWithRequest:(JDBaseRequest *)request error:(NSError *)error {
    request.error = error;
//    JDNetLog(@"Request %@ failed, status code = %ld, error = %@",
//           NSStringFromClass([request class]), (long)request.responseStatusCode, error.localizedDescription);
    NSString *str = [NSString stringWithFormat:@"请求 %@ 失败, 状态码 = %ld, 错误 = %@",
                     NSStringFromClass([request class]), (long)request.responseStatusCode, error.localizedDescription];
    JDNetLog(@"%@",str);
    [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];
    // Save incomplete download data.
    NSData *incompleteDownloadData = error.userInfo[NSURLSessionDownloadTaskResumeData];
    if (incompleteDownloadData) {// 如果有下载数据，则保存已下载的数据，用于断点续传
        [incompleteDownloadData writeToURL:[self incompleteDownloadTempPathForDownloadPath:request.resumableDownloadPath] atomically:YES];
    }

    // Load response from file and clean up if download task failed.
    if ([request.responseObject isKindOfClass:[NSURL class]]) { // 如果下载任务失败了，就清除返回的内容

        NSURL *url = request.responseObject;
        if (url.isFileURL && [[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
            request.responseData = [NSData dataWithContentsOfURL:url];
            request.responseString = [[NSString alloc] initWithData:request.responseData encoding:[JDNetworkUtils stringEncodingWithRequest:request]];

            [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        }
        request.responseObject = nil;
    }

    @autoreleasepool {
        [request requestFailedPreprocessor];// 子类继承重写可以进行一些处理
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [request toggleAccessoriesWillStopCallBack];// 回调JDRequestAccessory - requestWillStop
        [request requestFailedFilter];// 子类继承重写可以进行一些处理

        if (request.delegate != nil) {// delegate回调
            [request.delegate requestFailed:request];
        }
        if (request.failureCompletionBlock) {// block回调
            request.failureCompletionBlock(request);
        }
        [request toggleAccessoriesDidStopCallBack];// 回调JDRequestAccessory - requestDidStop
    });
}

- (void)addRequestToRecord:(JDBaseRequest *)request {
    Lock();
    _requestsRecord[@(request.requestTask.taskIdentifier)] = request;
    NSString *str = [NSString stringWithFormat:@"添加请求: %@后，请求队列还有: %zd",request, [_requestsRecord count]];
    JDNetLog(@"%@",str);
    [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];

    Unlock();
}

- (void)removeRequestFromRecord:(JDBaseRequest *)request {
    Lock();
    [_requestsRecord removeObjectForKey:@(request.requestTask.taskIdentifier)];
//    JDNetLog(@"Request queue size = %zd", [_requestsRecord count]);
    NSString *str = [NSString stringWithFormat:@"移除请求: %@ 后，请求队列还有: %zd",request, [_requestsRecord count]];
    JDNetLog(@"%@",str);
    [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];
    Unlock();
}

#pragma mark - 除下载外的，其他请求任务创建方法

- (NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
                               requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                       URLString:(NSString *)URLString
                                      parameters:(id)parameters
                                           error:(NSError * _Nullable __autoreleasing *)error {
     return [self dataTaskWithHTTPMethod:method requestSerializer:requestSerializer URLString:URLString parameters:parameters progress:nil constructingBodyWithBlock:nil error:error];
}
/**
 除下载外的，其他请求任务创建方法
 
 @param method 请求方法
 @param requestSerializer 请求序列
 @param URLString 请求url
 @param parameters 参数
 @param block 构造文件或富文本等上传内容，nil时不处理
 @param error 失败参
 @return 返回 NSURLSessionDataTask
 */
//- (NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
//                               requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
//                                       URLString:(NSString *)URLString
//                                      parameters:(id)parameters
//                       constructingBodyWithBlock:(nullable void (^)(id <AFMultipartFormData> formData))block
//                                           error:(NSError * _Nullable __autoreleasing *)error {
//    NSMutableURLRequest *request = nil;
//
//    if (block) {// 如果有上传内容，用此方法构造request
//        request = [requestSerializer multipartFormRequestWithMethod:method URLString:URLString parameters:parameters constructingBodyWithBlock:block error:error];
//    } else {// 其他请求request
//        request = [requestSerializer requestWithMethod:method URLString:URLString parameters:parameters error:error];
//    }
//
//    __block NSURLSessionDataTask *dataTask = nil;
//    dataTask = [_manager dataTaskWithRequest:request
//                           completionHandler:^(NSURLResponse * __unused response, id responseObject, NSError *_error) {
//                               [self handleRequestResult:dataTask responseObject:responseObject error:_error];
//                           }];
//
//    return dataTask;
//}
/**
 除下载外的，其他请求任务创建方法
 
 @param method 请求方法
 @param requestSerializer 请求序列
 @param URLString 请求url
 @param parameters 参数
 @param block 构造文件或富文本等上传内容，nil时不处理
 @param error 失败参
 @return 返回 NSURLSessionDataTask
 */
- (NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
                               requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                       URLString:(NSString *)URLString
                                      parameters:(id)parameters
                                        progress:(nullable void (^)(NSProgress *uploadProgress))progressBlock
                       constructingBodyWithBlock:(nullable void (^)(id <AFMultipartFormData> formData))block
                                           error:(NSError * _Nullable __autoreleasing *)error {
    NSMutableURLRequest *request = nil;
    if (block) { // 如果有上传内容，用此方法构造request
        request = [requestSerializer multipartFormRequestWithMethod:method URLString:URLString parameters:parameters constructingBodyWithBlock:block error:error];
    } else { // 其他请求request
        request = [requestSerializer requestWithMethod:method URLString:URLString parameters:parameters error:error];
    }
    
    __block NSURLSessionDataTask *dataTask = nil;
    dataTask = [_manager dataTaskWithRequest:request uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
        if (progressBlock) {
            progressBlock(uploadProgress);
        }
    } downloadProgress:NULL completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable _error) {
        [self handleRequestResult:dataTask responseObject:responseObject error:_error];
    }];
    
    return dataTask;
}

/**
 下载任务创建
 
 @param downloadPath 下载到哪里
 @param requestSerializer 请求序列
 @param URLString 请求url
 @param parameters 请求参
 @param downloadProgressBlock 进度回调
 @param error 失败
 @return 返回NSURLSessionDownloadTask
 */
- (NSURLSessionDownloadTask *)downloadTaskWithDownloadPath:(NSString *)downloadPath
                                         requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                                 URLString:(NSString *)URLString
                                                parameters:(id)parameters
                                                  progress:(nullable void (^)(NSProgress *downloadProgress))downloadProgressBlock
                                                     error:(NSError * _Nullable __autoreleasing *)error {
    // add parameters to URL;
    // 使用AFURLRequestSerialization的方法，追加参数到url中，并创建请求
    NSMutableURLRequest *urlRequest = [requestSerializer requestWithMethod:@"GET" URLString:URLString parameters:parameters error:error];

    NSString *downloadTargetPath;
    BOOL isDirectory;
    if(![[NSFileManager defaultManager] fileExistsAtPath:downloadPath isDirectory:&isDirectory]) {
        isDirectory = NO;// 文件不存在时，设为NO，否则根据情况来定isDirectory
    }
    // If targetPath is a directory, use the file name we got from the urlRequest.
    // Make sure downloadTargetPath is always a file, not directory.
    // 确保downloadTargetPath始终是个文件而不是目录
    if (isDirectory) {// 如果是目录，则使用urlRequest的文件名
        NSString *fileName = [urlRequest.URL lastPathComponent];
        downloadTargetPath = [NSString pathWithComponents:@[downloadPath, fileName]];
    } else {
        downloadTargetPath = downloadPath;
    }

    // AFN use `moveItemAtURL` to move downloaded file to target path,
    // this method aborts the move attempt if a file already exist at the path.
    // So we remove the exist file before we start the download task.
    // https://github.com/AFNetworking/AFNetworking/issues/3775
    // AFN 会使用 moveItemAtURL 方法，将下载文件移到目标路径
    // 可能会出问题，查看 https://github.com/AFNetworking/AFNetworking/issues/3775
    // 所以，这里在开始之前移除已存在文件
    if ([[NSFileManager defaultManager] fileExistsAtPath:downloadTargetPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:downloadTargetPath error:nil];
    }
    // 判断断点续传的文件是否存在
    BOOL resumeDataFileExists = [[NSFileManager defaultManager] fileExistsAtPath:[self incompleteDownloadTempPathForDownloadPath:downloadPath].path];
    NSData *data = [NSData dataWithContentsOfURL:[self incompleteDownloadTempPathForDownloadPath:downloadPath]];
    BOOL resumeDataIsValid = [JDNetworkUtils validateResumeData:data];// 判断已存在的文件是否可用

    BOOL canBeResumed = resumeDataFileExists && resumeDataIsValid;// 可以使用已存在文件
    BOOL resumeSucceeded = NO;
    __block NSURLSessionDownloadTask *downloadTask = nil;
    // Try to resume with resumeData.
    // Even though we try to validate the resumeData, this may still fail and raise excecption.
    if (canBeResumed) { // 如果存在文件可用，则直接进行文件恢复
        @try {
            downloadTask = [_manager downloadTaskWithResumeData:data progress:downloadProgressBlock destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                // destination是目标路径的意思
                return [NSURL fileURLWithPath:downloadTargetPath isDirectory:NO];
            } completionHandler:
                            ^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                                [self handleRequestResult:downloadTask responseObject:filePath error:error];
                            }];
            resumeSucceeded = YES;
        } @catch (NSException *exception) {
//            JDNetLog(@"Resume download failed, reason = %@", exception.reason);
            NSString *str = [NSString stringWithFormat:@"恢复缓存的下载文件失败，原因是: %@", exception.reason];
            JDNetLog(@"%@",str);
            [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];
            resumeSucceeded = NO;
        }
    }
    if (!resumeSucceeded) {// 如果恢复缓存文件失败，则进入下载
        downloadTask = [_manager downloadTaskWithRequest:urlRequest progress:downloadProgressBlock destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            return [NSURL fileURLWithPath:downloadTargetPath isDirectory:NO];
        } completionHandler:
                        ^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                            [self handleRequestResult:downloadTask responseObject:filePath error:error];
                        }];
    }
    return downloadTask;
}

#pragma mark - Resumable Download

/**
  临时下载的缓存路径

 @return path
 */
- (NSString *)incompleteDownloadTempCacheFolder {
    NSFileManager *fileManager = [NSFileManager new];
    static NSString *cacheFolder;

    if (!cacheFolder) {
        NSString *cacheDir = NSTemporaryDirectory();
        cacheFolder = [cacheDir stringByAppendingPathComponent:kJDNetworkIncompleteDownloadFolderName];
    }

    NSError *error = nil;
    if(![fileManager createDirectoryAtPath:cacheFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
//        JDNetLog(@"Failed to create cache directory at %@", cacheFolder);
        NSString *str = [NSString stringWithFormat:@"创建缓存目录失败，路径是: %@,错误是: %@", cacheFolder,error];
        JDNetLog(@"%@",str);
        [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];
        cacheFolder = nil;
    }
    return cacheFolder;
}

/**
 获取下载的临时文件全路径

 @param downloadPath downloadPath
 @return URL
 */
- (NSURL *)incompleteDownloadTempPathForDownloadPath:(NSString *)downloadPath {
    NSString *tempPath = nil;
    NSString *md5URLString = [JDNetworkUtils md5StringFromString:downloadPath];
    tempPath = [[self incompleteDownloadTempCacheFolder] stringByAppendingPathComponent:md5URLString];
    return [NSURL fileURLWithPath:tempPath];
}

#pragma mark - 用于测试
- (AFHTTPSessionManager *)manager {
    return _manager;
}

- (void)resetURLSessionManager {
    _manager = [AFHTTPSessionManager manager];
}

- (void)resetURLSessionManagerWithConfiguration:(NSURLSessionConfiguration *)configuration {
    _manager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:configuration];
}

@end
