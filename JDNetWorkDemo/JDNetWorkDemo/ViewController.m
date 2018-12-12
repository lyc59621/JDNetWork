//
//  ViewController.m
//  JDNetWorkDemo
//
//  Created by JDragon on 2018/8/25.
//  Copyright © 2018年 JDragon. All rights reserved.
//

#import "ViewController.h"
#import "TestJDNet.h"
#import "JDNetwork.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    JDNetworkConfig *config = [JDNetworkConfig sharedConfig];
    config.debugLogEnabled = YES; // 总开关
    config.developerLogEnabled = YES;
    config.logHeaderInfoEnabled = true;
    config.logResponseObjectEnabled = YES;
    config.logResponseStringEnabled = YES;
    config.logCacheMetaDataEnabled = NO;
    config.logCookieEnabled = NO;
    config.logRestfulEnabled = NO;
    TestJDNet *reg = [[TestJDNet alloc] init];
    [reg startWithCompletionBlockWithSuccess:^(__kindof JDBaseRequest * _Nonnull request) {
        
        NSLog(@"=====%@",request.responseObject);
    } failure:^(__kindof JDBaseRequest * _Nonnull request) {
        
    }];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
