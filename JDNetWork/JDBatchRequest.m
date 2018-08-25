//
//  JDBatchRequest.m
//  JDNetWork
//
//  Created by JDragon on 2018/8/25.
//  Copyright © 2018年 JDragon. All rights reserved.
//
#import "JDBatchRequest.h"
#import "JDNetworkPrivate.h"
#import "JDBatchRequestAgent.h"
#import "JDRequest.h"

@interface JDBatchRequest() <JDRequestDelegate>

/**
 完成的请求数量
 */
@property (nonatomic) NSInteger finishedCount;

@end

@implementation JDBatchRequest

- (instancetype)initWithRequestArray:(NSArray<JDRequest *> *)requestArray {
    self = [super init];
    if (self) {
        _requestArray = [requestArray copy];
        _finishedCount = 0;
        for (JDRequest * req in _requestArray) {
            if (![req isKindOfClass:[JDRequest class]]) {
                JDNetLog(@"错误，所有的请求项必须是 JDRequest 实例\nError, request item must be JDRequest instance.");
                return nil;
            }
        }
    }
    return self;
}

- (void)start {
    if (_finishedCount > 0) {
        JDNetLog(@"错误！请求已经开始\nError! Batch request has already started.");
        return;
    }
    _failedRequest = nil;
    [[JDBatchRequestAgent sharedAgent] addBatchRequest:self];//回调JDRequestAccessory - will start
    [self toggleAccessoriesWillStartCallBack];
    for (JDRequest * req in _requestArray) {
        req.delegate = self;
        [req clearCompletionBlock];// 清除block，使用代理方式
        [req start];// 开始
    }
}

- (void)stop {
    [self toggleAccessoriesWillStopCallBack]; // 回调JDRequestAccessory - will stop
    _delegate = nil;
    [self clearRequest]; // 停止所有的请求
    [self toggleAccessoriesDidStopCallBack]; // 回调JDRequestAccessory - did stop
    [[JDBatchRequestAgent sharedAgent] removeBatchRequest:self];// 移除自己
}

- (void)startWithCompletionBlockWithSuccess:(void (^)(JDBatchRequest *batchRequest))success
                                    failure:(void (^)(JDBatchRequest *batchRequest))failure {
    [self setCompletionBlockWithSuccess:success failure:failure];
    [self start];
}

- (void)setCompletionBlockWithSuccess:(void (^)(JDBatchRequest *batchRequest))success
                              failure:(void (^)(JDBatchRequest *batchRequest))failure {
    self.successCompletionBlock = success;
    self.failureCompletionBlock = failure;
}

/**
  清除block
 */
- (void)clearCompletionBlock {
    // nil out to break the retain cycle.
    self.successCompletionBlock = nil;
    self.failureCompletionBlock = nil;
}

/**
 判断所有的请求是否是cache

 @return <#return value description#>
 */
- (BOOL)isDataFromCache {
    BOOL result = YES;
    for (JDRequest *request in _requestArray) {
        if (!request.isDataFromCache) {
            result = NO;
        }
    }
    return result;
}


- (void)dealloc {
    [self clearRequest];
}

#pragma mark - Network Request Delegate

/**
 一个请求完成时

 @param request <#request description#>
 */
- (void)requestFinished:(JDRequest *)request {
    _finishedCount++;// 完成数+1
    if (_finishedCount == _requestArray.count) {// 如果请求完成时
        [self toggleAccessoriesWillStopCallBack];// 回调JDRequestAccessory - will stop
        if ([_delegate respondsToSelector:@selector(batchRequestFinished:)]) {
            [_delegate batchRequestFinished:self];// 完成回调
        }
        if (_successCompletionBlock) {// 如果有block，则block回调
            _successCompletionBlock(self);
        }
        [self clearCompletionBlock];// 清除block
        [self toggleAccessoriesDidStopCallBack];// 回调JDRequestAccessory - did stop
        [[JDBatchRequestAgent sharedAgent] removeBatchRequest:self];
    }
}

/**
 如果有一个请求失败，则全部请求失败

 @param request <#request description#>
 */
- (void)requestFailed:(JDRequest *)request {
    _failedRequest = request;
    [self toggleAccessoriesWillStopCallBack];
    // Stop 停止
    for (JDRequest *req in _requestArray) {
        [req stop];
    }
    // Callback 回调
    if ([_delegate respondsToSelector:@selector(batchRequestFailed:)]) {
        [_delegate batchRequestFailed:self];
    }
    if (_failureCompletionBlock) {
        _failureCompletionBlock(self);
    }
    // Clear 清除回调
    [self clearCompletionBlock];

    [self toggleAccessoriesDidStopCallBack];
    [[JDBatchRequestAgent sharedAgent] removeBatchRequest:self];
}

/**
 停止所有的请求
 */
- (void)clearRequest {
    for (JDRequest * req in _requestArray) {
        [req stop];
    }
    [self clearCompletionBlock];
}

#pragma mark - Request Accessoies

- (void)addAccessory:(id<JDRequestAccessory>)accessory {
    if (!self.requestAccessories) {
        self.requestAccessories = [NSMutableArray array];
    }
    [self.requestAccessories addObject:accessory];
}

@end
