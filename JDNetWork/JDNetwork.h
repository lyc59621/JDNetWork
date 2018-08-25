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

#if __has_include(<JDNetwork/JDNetwork.h>)

    FOUNDATION_EXPORT double JDNetworkVersionNumber;
    FOUNDATION_EXPORT const unsigned char JDNetworkVersionString[];

    #import <JDNetwork/JDRequest.h>
    #import <JDNetwork/JDBaseRequest.h>
    #import <JDNetwork/JDNetworkAgent.h>
    #import <JDNetwork/JDBatchRequest.h>
    #import <JDNetwork/JDBatchRequestAgent.h>
    #import <JDNetwork/JDChainRequest.h>
    #import <JDNetwork/JDChainRequestAgent.h>
    #import <JDNetwork/JDNetworkConfig.h>

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
