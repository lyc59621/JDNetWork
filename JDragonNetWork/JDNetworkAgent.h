//
//  JDNetworkAgent.h
//  JDNetWork
//
//  Created by JDragon on 2018/8/25.
//  Copyright © 2018年 JDragon. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class JDBaseRequest;



/**
 JDNetworkAgent is the underlying class that handles actual request generation,
 serialization and response handling.
 单例， 真正的网络请求控制类
 */
@interface JDNetworkAgent : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
  Get the shared agent.
  获取单例请求

 @return <#return value description#>
 */
+ (JDNetworkAgent *)sharedAgent;

/**
 Add request to session and start it.
 添加request 并调用start开始

 @param request <#request description#>
 */
- (void)addRequest:(JDBaseRequest *)request;

/**
  Cancel a request that was previously added.
  取消之前添加的request 请求

 @param request <#request description#>
 */
- (void)cancelRequest:(JDBaseRequest *)request;

/**
 Cancel all requests that were previously added.
  取消所有的请求
 */
- (void)cancelAllRequests;

/**
 根据JDBaseRequest的设置返回最后的url               Return the constructed URL of request.

 @param request                                 request The request to parse. Should not be nil.
 @return url                                    return The result URL.
 */
- (NSString *)buildRequestUrl:(JDBaseRequest *)request;

@end

NS_ASSUME_NONNULL_END
