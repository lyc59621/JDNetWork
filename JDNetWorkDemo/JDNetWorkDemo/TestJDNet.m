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
      return @"https://dev.zmmovie.com/api/v1/account/mobile/verifyForIOS";
}

- (JDRequestMethod)requestMethod {
    return JDRequestMethodPOST;
}

- (id)requestArgument {
    return @{
             @"mobile": @"18809098989",
             @"phonecode": @"86",
             @"version":@"1_0_0_1"
             };
}

@end
