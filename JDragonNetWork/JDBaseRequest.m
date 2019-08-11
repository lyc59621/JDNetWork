//
//  JDBaseRequest.m
//  JDNetWork
//
//  Created by JDragon on 2018/8/25.
//  Copyright © 2018年 JDragon. All rights reserved.
//

#import "JDBaseRequest.h"
#import "JDNetworkAgent.h"
#import "JDNetworkPrivate.h"

#if __has_include(<AFNetworking/AFNetworking.h>)
#import <AFNetworking/AFNetworking.h>
#else
#import "AFNetworking.h"
#endif
//请求错误域
NSString *const JDRequestValidationErrorDomain = @"com.jdragon.request.validation";

@interface JDBaseRequest ()

@property (nonatomic, strong, readwrite) NSURLSessionTask *requestTask;
@property (nonatomic, strong, readwrite) NSData *responseData;
@property (nonatomic, strong, readwrite) id responseJSONObject;
@property (nonatomic, strong, readwrite) id responseObject;
@property (nonatomic, strong, readwrite) NSString *responseString;
@property (nonatomic, strong, readwrite) NSError *error;

@end

@implementation JDBaseRequest

#pragma mark - Request and Response Information  请求和返回信息

- (NSHTTPURLResponse *)response {
    return (NSHTTPURLResponse *)self.requestTask.response;
}

- (NSInteger)responseStatusCode {
    return self.response.statusCode;
}

- (NSDictionary *)responseHeaders {
    return self.response.allHeaderFields;
}

- (NSURLRequest *)currentRequest {
    return self.requestTask.currentRequest;
}

- (NSURLRequest *)originalRequest {
    return self.requestTask.originalRequest;
}

- (BOOL)isCancelled {
    if (!self.requestTask) {
        return NO;
    }
    return self.requestTask.state == NSURLSessionTaskStateCanceling;
}

- (BOOL)isExecuting {
    if (!self.requestTask) {
        return NO;
    }
    return self.requestTask.state == NSURLSessionTaskStateRunning;
}

#pragma mark - Request Configuration 请求配置

- (void)setCompletionBlockWithSuccess:(JDRequestCompletionBlock)success
                              failure:(JDRequestCompletionBlock)failure {
    self.successCompletionBlock = success;
    self.failureCompletionBlock = failure;
}

- (void)clearCompletionBlock {
    // nil out to break the retain cycle.
    // 设置nil，跳出retain循环
    self.successCompletionBlock = nil;
    self.failureCompletionBlock = nil;
}

- (void)addAccessory:(id<JDRequestAccessory>)accessory {
    if (!self.requestAccessories) {
        self.requestAccessories = [NSMutableArray array];
    }
    [self.requestAccessories addObject:accessory];
}

#pragma mark - Request Action  请求动作

- (void)start {
    [self toggleAccessoriesWillStartCallBack]; // 回调JDRequestAccessory - requestWillStart
    [[JDNetworkAgent sharedAgent] addRequest:self]; // 追加请求记录
}

- (void)stop {
    [self toggleAccessoriesWillStopCallBack]; // 回调JDRequestAccessory - requestWillStop
    self.delegate = nil;
    [[JDNetworkAgent sharedAgent] cancelRequest:self]; // 取消请求
    [self toggleAccessoriesDidStopCallBack]; // 回调JDRequestAccessory - requestDidStop
}

- (void)startWithCompletionBlockWithSuccess:(JDRequestCompletionBlock)success
                                    failure:(JDRequestCompletionBlock)failure {
    [self setCompletionBlockWithSuccess:success failure:failure];
    [self start];
}

#pragma mark - Subclass Override   子类可以重写的

- (void)requestCompletePreprocessor {
}

- (void)requestCompleteFilter {
}

- (void)requestFailedPreprocessor {
}

- (void)requestFailedFilter {
}

- (NSString *)requestUrl {
    return @"";
}

- (NSString *)cdnUrl {
    return @"";
}

- (NSString *)baseUrl {
    return @"";
}

- (NSTimeInterval)requestTimeoutInterval {
    return 60;
}

- (id)requestArgument {
    return nil;
}

- (id)cacheFileNameFilterForRequestArgument:(id)argument {
    return argument;
}

- (JDRequestMethod)requestMethod {
    return JDRequestMethodGET;
}

- (JDRequestSerializerType)requestSerializerType {
    return JDRequestSerializerTypeHTTP;
}

- (JDResponseSerializerType)responseSerializerType {
    return JDResponseSerializerTypeJSON;
}

- (NSArray *)requestAuthorizationHeaderFieldArray {
    return nil;
}

- (NSDictionary *)requestHeaderFieldValueDictionary {
    return nil;
}

- (NSURLRequest *)buildCustomUrlRequest {
    return nil;
}

- (BOOL)useCDN {
    return NO;
}

- (BOOL)allowsCellularAccess {
    return YES;
}

- (id)jsonValidator {
    return nil;
}

- (BOOL)statusCodeValidator {
    NSInteger statusCode = [self responseStatusCode];
    return (statusCode >= 200 && statusCode <= 299);
}

#pragma mark - NSObject

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>{ URL: %@ } { method: %@ } { arguments: %@ }", NSStringFromClass([self class]), self, self.currentRequest.URL, self.currentRequest.HTTPMethod, self.requestArgument];
}

@end
