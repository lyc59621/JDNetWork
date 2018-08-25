//
//  JDChainRequest.m
//  JDNetWork
//
//  Created by JDragon on 2018/8/25.
//  Copyright © 2018年 JDragon. All rights reserved.
//

#import "JDChainRequest.h"
#import "JDChainRequestAgent.h"
#import "JDNetworkPrivate.h"
#import "JDBaseRequest.h"

@interface JDChainRequest()<JDRequestDelegate>

@property (strong, nonatomic) NSMutableArray<JDBaseRequest *> *requestArray;
@property (strong, nonatomic) NSMutableArray<JDChainCallback> *requestCallbackArray;
@property (assign, nonatomic) NSUInteger nextRequestIndex;
@property (strong, nonatomic) JDChainCallback emptyCallback;

@end

@implementation JDChainRequest

- (instancetype)init {
    self = [super init];
    if (self) {
        _nextRequestIndex = 0;
        _requestArray = [NSMutableArray array];
        _requestCallbackArray = [NSMutableArray array];
        _emptyCallback = ^(JDChainRequest *chainRequest, JDBaseRequest *baseRequest) {
            // do nothing
        };
    }
    return self;
}

- (void)start {
    if (_nextRequestIndex > 0) {
//        JDNetLog(@"Error! Chain request has already started.");
        JDNetLog(@"错误! 串行请求已经开始");
        return;
    }

    if ([_requestArray count] > 0) {
        [self toggleAccessoriesWillStartCallBack];
        [self startNextRequest];// 开始下一个请求
        [[JDChainRequestAgent sharedAgent] addChainRequest:self];
    } else {
//        JDNetLog(@"Error! Chain request array is empty.");
        JDNetLog(@"错误! 串行请求为空");

    }
}

- (void)stop {
    [self toggleAccessoriesWillStopCallBack];
    [self clearRequest];
    [[JDChainRequestAgent sharedAgent] removeChainRequest:self];
    [self toggleAccessoriesDidStopCallBack];
}

- (void)addRequest:(JDBaseRequest *)request callback:(JDChainCallback)callback {
    [_requestArray addObject:request]; // 添加请求
    if (callback != nil) {
        [_requestCallbackArray addObject:callback];// 清加请求
    } else {// 这里增加空回调，为了保证数组与下标的对应
        [_requestCallbackArray addObject:_emptyCallback];
    }
}

- (NSArray<JDBaseRequest *> *)requestArray {
    return _requestArray;
}
/**
 启动下一个请求

 @return YES/NO  是否开始
 */
- (BOOL)startNextRequest {
    if (_nextRequestIndex < [_requestArray count]) {// 如果还有请求
        JDBaseRequest *request = _requestArray[_nextRequestIndex];
        _nextRequestIndex++;
        request.delegate = self;
        [request clearCompletionBlock];  // 清除block，只使用delegate代理方式
        [request start];
        return YES;
    } else {
        return NO;
    }
}

#pragma mark - Network Request Delegate


/**
 一个请求完成时

 @param request JDBaseRequest
 */
- (void)requestFinished:(JDBaseRequest *)request {
    NSUInteger currentRequestIndex = _nextRequestIndex - 1;// _nextRequestIndex 在 startNextRequest时+1了；
    JDChainCallback callback = _requestCallbackArray[currentRequestIndex];// 获取回调
    callback(self, request); // 回调
    if (![self startNextRequest]) {
        [self toggleAccessoriesWillStopCallBack];// 如果没有请求了，就完成了。进行总回调
        if ([_delegate respondsToSelector:@selector(chainRequestFinished:)]) {
            [_delegate chainRequestFinished:self];
            [[JDChainRequestAgent sharedAgent] removeChainRequest:self];
        }
        [self toggleAccessoriesDidStopCallBack];
    }
}

/**
  一个请求失败时

 @param request JDBaseRequest
 */
- (void)requestFailed:(JDBaseRequest *)request {
     // 单个请求完成，则直接认定为失败。并回调
    [self toggleAccessoriesWillStopCallBack];
    if ([_delegate respondsToSelector:@selector(chainRequestFailed:failedBaseRequest:)]) {
        [_delegate chainRequestFailed:self failedBaseRequest:request];
        [[JDChainRequestAgent sharedAgent] removeChainRequest:self];
    }
    [self toggleAccessoriesDidStopCallBack];
}

/**
 清除请求
 */
- (void)clearRequest {
    NSUInteger currentRequestIndex = _nextRequestIndex - 1;
    if (currentRequestIndex < [_requestArray count]) {
        JDBaseRequest *request = _requestArray[currentRequestIndex]; //找到当前的请求
        [request stop]; //并停止
    }
    [_requestArray removeAllObjects];
    [_requestCallbackArray removeAllObjects];
}

#pragma mark - Request Accessoies

- (void)addAccessory:(id<JDRequestAccessory>)accessory {
    if (!self.requestAccessories) {
        self.requestAccessories = [NSMutableArray array];
    }
    [self.requestAccessories addObject:accessory];
}

@end
