//
//  JDBatchRequestAgent.h
//  JDNetWork
//
//  Created by JDragon on 2018/8/25.
//  Copyright © 2018年 JDragon. All rights reserved.
//.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class JDBatchRequest;

/**
 JDBatchRequestAgent handles batch request management. It keeps track of all
 the batch requests.
 管理并行请求， 这个类跟踪所有并行请求
 */
@interface JDBatchRequestAgent : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 Get the shared batch request agent.
 单例
 @return <#return value description#>
 */
+ (JDBatchRequestAgent *)sharedAgent;

///

/**
 Add a batch request.
 添加一条并列请求

 @param request <#request description#>
 */
- (void)addBatchRequest:(JDBatchRequest *)request;

/**
 Remove a previously added batch request.
 移除之前存在的请求

 @param request <#request description#>
 */
- (void)removeBatchRequest:(JDBatchRequest *)request;

@end

NS_ASSUME_NONNULL_END
