//
//  JDBatchRequest.h
//  JDNetWork
//
//  Created by JDragon on 2018/8/25.
//  Copyright © 2018年 JDragon. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class JDRequest;
@class JDBatchRequest;
@protocol JDRequestAccessory;



/**
 The JDBatchRequestDelegate protocol defines several optional methods you can use
 to receive network-related messages. All the delegate methods will be called
 on the main queue. Note the delegate methods will be called when all the requests
 of batch request finishes.
 所有请求完成后，在主线程中回调
 */
@protocol JDBatchRequestDelegate <NSObject>

@optional
///  Tell the delegate that the batch request has finished successfully/
///  成功时回调
///  @param batchRequest The corresponding batch request.
- (void)batchRequestFinished:(JDBatchRequest *)batchRequest;

///  Tell the delegate that the batch request has failed.
///  失败时回调
///  @param batchRequest The corresponding batch request.
- (void)batchRequestFailed:(JDBatchRequest *)batchRequest;

@end
/**
  JDBatchRequest can be used to batch several JDRequest. Note that when used inside JDBatchRequest, a single
  JDRequest will have its own callback and delegate cleared, in favor of the batch request callback.
  并行请求，统一返回,单个失败时，定义为整个请求失败
 */
@interface JDBatchRequest : NSObject

/**
 All the requests are stored in this array
 所有的请求都被保存在这个数组里面
 */
@property (nonatomic, strong, readonly) NSArray<JDRequest *> *requestArray;

/**
 The delegate object of the batch request. Default is nil.
 请求回调delegate，默认是nil
 */
@property (nonatomic, weak, nullable) id<JDBatchRequestDelegate> delegate;

/**
 The success callback. Note this will be called only if all the requests are finished.
 This block will be called on the main queue.
 成功的回调。
 所有的请求都完成时，将在 主线程 中回调
 */
@property (nonatomic, copy, nullable) void (^successCompletionBlock)(JDBatchRequest *);

/**
 The failure callback. Note this will be called if one of the requests fails.
 This block will be called on the main queue.
 失败的回调。
 只要有一个请求失败，就会在 主线程 中回调
 */
@property (nonatomic, copy, nullable) void (^failureCompletionBlock)(JDBatchRequest *);

/**
  Tag can be used to identify batch request. Default value is 0.
  请求标记，默认是0
 */
@property (nonatomic) NSInteger tag;

/**
 This can be used to add several accossories object. Note if you use `addAccessory` to add acceesory
 this array will be automatically created. Default is nil.
 记录JDRequestAccessory的集合，默认是nil；
 使用addAccessory方法添加时，数组将被自动初始化
 */
@property (nonatomic, strong, nullable) NSMutableArray<id<JDRequestAccessory>> *requestAccessories;

/**
 The first request that failed (and causing the batch request to fail).
 第一个导致请求列失败的请求
 */
@property (nonatomic, strong, readonly, nullable) JDRequest *failedRequest;

///  Creates a `JDBatchRequest` with a bunch of requests.
///
///  @param requestArray requests useds to create batch request.
///

/**
 Creates a `JDBatchRequest` with a bunch of requests.
 @param requestArray requests useds to create batch request.
 创建多个请求的初始化方法
 @param requestArray NSArray<JDRequest *> *
 @return JDRequest
 */
- (instancetype)initWithRequestArray:(NSArray<JDRequest *> *)requestArray;

/**
 Set completion callbacks
 一些回调

 @param success <#success description#>
 @param failure <#failure description#>
 */
- (void)setCompletionBlockWithSuccess:(nullable void (^)(JDBatchRequest *batchRequest))success
                              failure:(nullable void (^)(JDBatchRequest *batchRequest))failure;

/**
 Nil out both success and failure callback blocks.
 清除回调
 */
- (void)clearCompletionBlock;

/**
  Convenience method to add request accessory. See also `requestAccessories`.
  配合 requestAccessories 使用
 @param accessory <#accessory description#>
 */
- (void)addAccessory:(id<JDRequestAccessory>)accessory;

/**
 请求开始，将追加所有的请求到队列中
 */
- (void)start;

/**
  Stop all the requests of the batch request.
 停止所有的请求
 */
- (void)stop;

/**
 Convenience method to start the batch request with block callbacks.
 直接以block的方式开始

 @param success 成功Block回调
 @param failure 失败Block回调
 */
- (void)startWithCompletionBlockWithSuccess:(nullable void (^)(JDBatchRequest *batchRequest))success
                                    failure:(nullable void (^)(JDBatchRequest *batchRequest))failure;


/**
 Whether all response data is from local cache.
 是否 所有的返回数据是本地缓存

 @return <#return value description#>
 */
- (BOOL)isDataFromCache;

@end

NS_ASSUME_NONNULL_END
