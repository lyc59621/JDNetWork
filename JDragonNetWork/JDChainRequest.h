//
//  JDChainRequest.h
//  JDNetWork
//
//  Created by JDragon on 2018/8/25.
//  Copyright © 2018年 JDragon. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class JDChainRequest;
@class JDBaseRequest;
@protocol JDRequestAccessory;



/**
  The JDChainRequestDelegate protocol defines several optional methods you can use
  to receive network-related messages. All the delegate methods will be called
  on the main queue. Note the delegate methods will be called when all the requests
  of chain request finishes.
  在主线程中回调
 */
@protocol JDChainRequestDelegate <NSObject>

@optional

/**
 Tell the delegate that the chain request has finished successfully.
 
 @param chainRequest The corresponding chain request.
 所有的请求完成

 @param chainRequest JDChainRequest
 */
- (void)chainRequestFinished:(JDChainRequest *)chainRequest;

/**
 第一个请求失败时，就会被回调                                       Tell the delegate that the chain request has failed.
 @param chainRequest 当前请求序列                               The corresponding chain request.
 @param request 俗话说一个老鼠屎坏了一锅汤，这就是那个屎              First failed request that causes the whole request to fail.
 */
- (void)chainRequestFailed:(JDChainRequest *)chainRequest failedBaseRequest:(JDBaseRequest*)request;

@end

typedef void (^JDChainCallback)(JDChainRequest *chainRequest, JDBaseRequest *baseRequest);


/**
 JDBatchRequest can be used to chain several JDRequest so that one will only starts after another finishes.
 Note that when used inside JDChainRequest, a single JDRequest will have its own callback and delegate
  cleared, in favor of the batch request callback.
 串行依赖请求
 */
@interface JDChainRequest : NSObject

/**
 All the requests are stored in this array.
  所有的串行请求

 @return NSArray<JDBaseRequest *> *
 */
- (NSArray<JDBaseRequest *> *)requestArray;

/**
  The delegate object of the chain request. Default is nil.
  delegate回调，默认是nil
 */
@property (nonatomic, weak, nullable) id<JDChainRequestDelegate> delegate;

/**
  This can be used to add several accossories object. Note if you use `addAccessory` to add acceesory
  this array will be automatically created. Default is nil.
  请求状态监听
 */
@property (nonatomic, strong, nullable) NSMutableArray<id<JDRequestAccessory>> *requestAccessories;

/**
  Convenience method to add request accessory. See also `requestAccessories`.
  添加要监听的状态

 @param accessory JDRequestAccessory
 */
- (void)addAccessory:(id<JDRequestAccessory>)accessory;

/**
  Start the chain request, adding first request in the chain to request queue.
  从序列中的第一个开始请求
 */
- (void)start;

/**
 Stop the chain request. Remaining request in chain will be cancelled.
 停止请求，还存在的请求，将被中止
 */
- (void)stop;

/**
 向队列中添加请求                                Add request to request chain.
 
 @param request 添加哪个请求                    The request to be chained.
 @param callback 当前请求完成时的回调             The finish callback
 */
- (void)addRequest:(JDBaseRequest *)request callback:(nullable JDChainCallback)callback;

@end

NS_ASSUME_NONNULL_END
