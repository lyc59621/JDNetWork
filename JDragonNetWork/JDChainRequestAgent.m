//
//  JDChainRequestAgent.m
//  JDNetWork
//
//  Created by JDragon on 2018/8/25.
//  Copyright © 2018年 JDragon. All rights reserved.
//

#import "JDChainRequestAgent.h"
#import "JDChainRequest.h"

@interface JDChainRequestAgent()

@property (strong, nonatomic) NSMutableArray<JDChainRequest *> *requestArray;

@end

@implementation JDChainRequestAgent

+ (JDChainRequestAgent *)sharedAgent {
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
        _requestArray = [NSMutableArray array];
    }
    return self;
}

- (void)addChainRequest:(JDChainRequest *)request {
    @synchronized(self) {
        [_requestArray addObject:request];
    }
}

- (void)removeChainRequest:(JDChainRequest *)request {
    @synchronized(self) {
        [_requestArray removeObject:request];
    }
}

@end
