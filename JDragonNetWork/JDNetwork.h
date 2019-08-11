//
//  JDNetwork.h
//  JDNetWork
//
//  Created by JDragon on 2018/8/25.
//  Copyright © 2018年 JDragon. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef _JDNETWORK_
#define _JDNETWORK_

#if __has_include(<JDragonNetWork/JDNetwork.h>)

FOUNDATION_EXPORT double JDNetworkVersionNumber;
FOUNDATION_EXPORT const unsigned char JDNetworkVersionString[];

#import <JDragonNetWork/JDRequest.h>
#import <JDragonNetWork/JDBaseRequest.h>
#import <JDragonNetWork/JDNetworkAgent.h>
#import <JDragonNetWork/JDBatchRequest.h>
#import <JDragonNetWork/JDBatchRequestAgent.h>
#import <JDragonNetWork/JDChainRequest.h>
#import <JDragonNetWork/JDChainRequestAgent.h>
#import <JDragonNetWork/JDNetworkConfig.h>

#else

#import "JDRequest.h"
#import "JDBaseRequest.h"
#import "JDNetworkAgent.h"
#import "JDBatchRequest.h"
#import "JDBatchRequestAgent.h"
#import "JDChainRequest.h"
#import "JDChainRequestAgent.h"
#import "JDNetworkConfig.h"

#endif /* __has_include */

#endif /* _JDNETWORK_ */

