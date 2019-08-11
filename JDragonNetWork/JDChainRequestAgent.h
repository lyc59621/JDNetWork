//
//  JDChainRequestAgent.h
//  JDNetWork
//
//  Created by JDragon on 2018/8/25.
//  Copyright © 2018年 JDragon. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class JDChainRequest;

/**
 JDChainRequestAgent handles chain request management. It keeps track of all
 the chain requests.
 管理所有的串行请求
 */
@interface JDChainRequestAgent : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 单例

 @return JDChainRequestAgent
 */
+ (JDChainRequestAgent *)sharedAgent;

/**
  添加一个串行请求

 @param request JDChainRequest
 */
- (void)addChainRequest:(JDChainRequest *)request;

/**
 移除一个串行请求

 @param request JDChainRequest
 */
- (void)removeChainRequest:(JDChainRequest *)request;

@end

NS_ASSUME_NONNULL_END
