//
//  TestJDNet.m
//  JDNetWorkDemo
//
//  Created by JDragon on 2018/8/25.
//  Copyright © 2018年 JDragon. All rights reserved.
//

#import "TestJDNet.h"

@implementation TestJDNet


- (NSString *)requestUrl {
    return @"";
}

- (JDRequestMethod)requestMethod {
    return JDRequestMethodPOST;
}

- (id)requestArgument {
    return @{
             @"mobile": @"999999",
             @"phonecode": @"86",
             @"version":@"1_0_0_1"
             };
}

@end
