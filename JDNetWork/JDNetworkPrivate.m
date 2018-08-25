//
//  JDNetworkPrivate.m
//  JDNetWork
//
//  Created by JDragon on 2018/8/25.
//  Copyright © 2018年 JDragon. All rights reserved.
//

#import <CommonCrypto/CommonDigest.h>
#import "JDNetworkPrivate.h"
#import <objc/runtime.h>
#if __has_include(<AFNetworking/AFNetworking.h>)
#import <AFNetworking/AFURLRequestSerialization.h>
#else
#import "AFURLRequestSerialization.h"
#endif

void JDNetLog(NSString *format, ...) {
#ifdef DEBUG
    if (![JDNetworkConfig sharedConfig].debugLogEnabled) {
        return;
    }
    va_list argptr;
    va_start(argptr, format);
    NSLogv(format, argptr);
    va_end(argptr);
#endif
}

@implementation NSObject (get_property)

/**
 获取对象的所有属性 以及属性值
 
 @return NSDictionary
 */
- (NSDictionary *)ecn_getAllPropertyValues
{
    NSMutableDictionary *props = [NSMutableDictionary dictionary];
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    for (i = 0; i<outCount; i++)
    {
        objc_property_t property = properties[i];
        const char* char_f =property_getName(property);
        NSString *propertyName = [NSString stringWithUTF8String:char_f];
        id propertyValue = [self valueForKey:(NSString *)propertyName];
        if (propertyValue) [props setObject:propertyValue forKey:propertyName];
    }
    free(properties);
    return props;
}

@end
@implementation JDNetworkUtils

/**
 json验证，block只有当失败时才有返回

 @param json json
 @param jsonValidator jsonValidator
 @return YES/NO
 */
+ (BOOL)validateJSON:(id)json withValidator:(id)jsonValidator failedJsonBlock:(void(^)(NSDictionary *failedData))block{
    if ([json isKindOfClass:[NSDictionary class]] &&
        [jsonValidator isKindOfClass:[NSDictionary class]]) {
        NSDictionary * dict = json;
        NSDictionary * validator = jsonValidator;
        BOOL result = YES;
        NSEnumerator * enumerator = [validator keyEnumerator];
        NSString * key;
        while ((key = [enumerator nextObject]) != nil) {
            id value = dict[key];
            id format = validator[key];
            if ([value isKindOfClass:[NSDictionary class]]
                || [value isKindOfClass:[NSArray class]]) {
                result = [self validateJSON:value withValidator:format failedJsonBlock:block];
                if (!result) {
                    break;
                }
            } else {
                if ([value isKindOfClass:format] == NO &&
                    [value isKindOfClass:[NSNull class]] == NO) {
                    result = NO;
                    break;
                }
            }
        }
        if (!result) {
            id local_class = [validator[key] class];
            id json_class = [dict[key] class];
            NSString *str = [NSString stringWithFormat:@"*json校验--1失败的key: %@,json_class: %@ - local_class: %@",key,json_class,local_class];
            JDNetLog(@"%@",str);
            [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];
            if (block) {
                block(@{
                        @"key" : key,
                        @"local_class" : local_class,
                        @"json_class" : json_class
                        });
            }
        }
        return result;
    } else if ([json isKindOfClass:[NSArray class]] &&
               [jsonValidator isKindOfClass:[NSArray class]]) {
        NSArray * validatorArray = (NSArray *)jsonValidator;
        if (validatorArray.count > 0) {
            NSArray * array = json;
            NSDictionary * validator = jsonValidator[0];
            for (id item in array) {
                BOOL result = [self validateJSON:item withValidator:validator failedJsonBlock:block];
                if (!result) {
                    NSString *str = [NSString stringWithFormat:@"*json校验--2值的class: %@",[item class]];
                    JDNetLog(@"%@",str);
                    [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];
                    return NO;
                }
            }
        }
        return YES;
    } else if ([json isKindOfClass:jsonValidator]) {
        return YES;
    } else {
        NSString *str = [NSString stringWithFormat:@"*json校验--3 json_class: %@ - local_class: %@",[json class],[jsonValidator class]];
        JDNetLog(@"%@",str);
        [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];
        return NO;
    }
}

/**
 设置这个路径下面的内容不要进行系统备份

 @param path Path
 */
+ (void)addDoNotBackupAttribute:(NSString *)path {
    NSURL *url = [NSURL fileURLWithPath:path];
    NSError *error = nil;
    /**
     从iOS 5.1开始，应用可以使用NSURLIsExcludedFromBackupKey 或 kCFURLIsExcludedFromBackupKey 文件属性来防止文件被备份。
     这些API是通过通过旧的，弃用的方式的直接设置额外属性。所有运行在iOS5.1的都应该使用这些API包防止文件被备份
     */
    [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:&error];
    if (error) {
//        JDNetLog(@"error to set do not backup attribute, error = %@", error);
        NSString *str = [NSString stringWithFormat:@"设置数据不进行备份失败，错误是: %@", error];
        JDNetLog(@"%@",str);
        [JDNetworkUtils sendDebugLogNotification:@{@"log":str} fromClass:self];
    }
}

/**
  md5加密

 @param string NSString
 @return NSString
 */
+ (NSString *)md5StringFromString:(NSString *)string {
    NSParameterAssert(string != nil && [string length] > 0);

    const char *value = [string UTF8String];

    unsigned char outputBuffer[CC_MD5_DIGEST_LENGTH];
    CC_MD5(value, (CC_LONG)strlen(value), outputBuffer);

    NSMutableString *outputString = [[NSMutableString alloc] initWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(NSInteger count = 0; count < CC_MD5_DIGEST_LENGTH; count++){
        [outputString appendFormat:@"%02x", outputBuffer[count]];
    }

    return outputString;
}

/**
  获取APP版本 CFBundleShortVersionString

 @return NSString
 */
+ (NSString *)appVersionString {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
}

/**
 获取request的编码

 @param request JDBaseRequest
 @return NSStringEncoding
 */
+ (NSStringEncoding)stringEncodingWithRequest:(JDBaseRequest *)request {
    // From AFNetworking 2.6.3
    NSStringEncoding stringEncoding = NSUTF8StringEncoding;
    if (request.response.textEncodingName) {
        CFStringEncoding encoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)request.response.textEncodingName);
        if (encoding != kCFStringEncodingInvalidId) {
            stringEncoding = CFStringConvertEncodingToNSStringEncoding(encoding);
        }
    }
    return stringEncoding;
}

/**
 判断下载的一些数据是否可用

 @param data NSData
 @return YES/NO
 */
+ (BOOL)validateResumeData:(NSData *)data {
    // From http://stackoverflow.com/a/22137510/3562486
    if (!data || [data length] < 1) return NO;

    NSError *error;
    NSDictionary *resumeDictionary = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&error];
    if (!resumeDictionary || error) return NO;

    // Before iOS 9 & Mac OS X 10.11
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED < 90000)\
|| (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED < 101100)
    NSString *localFilePath = [resumeDictionary objectForKey:@"NSURLSessionResumeInfoLocalPath"];
    if ([localFilePath length] < 1) return NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:localFilePath];
#endif
    // After iOS 9 we can not actually detects if the cache file exists. This plist file has a somehow
    // complicated structue. Besides, the plist structure is different between iOS 9 and iOS 10.
    // We can only assume that the plist being successfully parsed means the resume data is valid.
    return YES;
}
/// 发送日志通知
+ (void)sendDebugLogNotification:(id)userInfo fromClass:(nullable NSObject *)object
{
    if ([JDNetworkConfig sharedConfig].developerLogEnabled) {
        if ([userInfo isKindOfClass:[NSDictionary class]]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:JDNetworkDebugLogNotification object:object userInfo:userInfo];
        }
    }
}
/// 删除一个串中，除大小写字母、数字、下划线以外的其他字符
+ (NSString *)regularStringByLetter_number:(NSString *)string
{
    NSString *hanzi = @"\\u4e00-\\u9fa5"; // 汉字
    NSString *characterRegex = [NSString stringWithFormat:@"(?:[%@A-Za-z0-9%@]+)", hanzi,@"_"]; // 及下划线
    NSRegularExpression *regular = [NSRegularExpression regularExpressionWithPattern:characterRegex options:0 error:NULL];
    __block NSString *finalStr = @"";
    [regular enumerateMatchesInString:string options:0 range:NSMakeRange(0, [string length]) usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        finalStr = [finalStr stringByAppendingString:[string substringWithRange:result.range]];
    }];
    return finalStr;
}
/// 将unicodejson串转成utf-8
+ (NSString *)translateUnicodeString:(NSString *)unicodeStr
{
    NSString *tempStr1 = [unicodeStr stringByReplacingOccurrencesOfString:@"\\u" withString:@"\\U"];
    NSString *tempStr2 = [tempStr1 stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    NSString *tempStr3 = [[@"\"" stringByAppendingString:tempStr2] stringByAppendingString:@"\""];
    NSData *tempData = [tempStr3 dataUsingEncoding:NSUTF8StringEncoding];
    NSString* returnStr = [NSPropertyListSerialization propertyListWithData:tempData options:NSPropertyListImmutable format:NULL error:NULL];
    return [returnStr stringByReplacingOccurrencesOfString:@"\\r\\n" withString:@"\n"];
}
@end

@implementation JDBaseRequest (RequestAccessory)

- (void)toggleAccessoriesWillStartCallBack {
    for (id<JDRequestAccessory> accessory in self.requestAccessories) {
        if ([accessory respondsToSelector:@selector(requestWillStart:)]) {
            [accessory requestWillStart:self];
        }
    }
}

- (void)toggleAccessoriesWillStopCallBack {
    for (id<JDRequestAccessory> accessory in self.requestAccessories) {
        if ([accessory respondsToSelector:@selector(requestWillStop:)]) {
            [accessory requestWillStop:self];
        }
    }
}

- (void)toggleAccessoriesDidStopCallBack {
    for (id<JDRequestAccessory> accessory in self.requestAccessories) {
        if ([accessory respondsToSelector:@selector(requestDidStop:)]) {
            [accessory requestDidStop:self];
        }
    }
}

@end

@implementation JDBatchRequest (RequestAccessory)

- (void)toggleAccessoriesWillStartCallBack {
    for (id<JDRequestAccessory> accessory in self.requestAccessories) {
        if ([accessory respondsToSelector:@selector(requestWillStart:)]) {
            [accessory requestWillStart:self];
        }
    }
}

- (void)toggleAccessoriesWillStopCallBack {
    for (id<JDRequestAccessory> accessory in self.requestAccessories) {
        if ([accessory respondsToSelector:@selector(requestWillStop:)]) {
            [accessory requestWillStop:self];
        }
    }
}

- (void)toggleAccessoriesDidStopCallBack {
    for (id<JDRequestAccessory> accessory in self.requestAccessories) {
        if ([accessory respondsToSelector:@selector(requestDidStop:)]) {
            [accessory requestDidStop:self];
        }
    }
}

@end

@implementation JDChainRequest (RequestAccessory)

- (void)toggleAccessoriesWillStartCallBack {
    for (id<JDRequestAccessory> accessory in self.requestAccessories) {
        if ([accessory respondsToSelector:@selector(requestWillStart:)]) {
            [accessory requestWillStart:self];
        }
    }
}

- (void)toggleAccessoriesWillStopCallBack {
    for (id<JDRequestAccessory> accessory in self.requestAccessories) {
        if ([accessory respondsToSelector:@selector(requestWillStop:)]) {
            [accessory requestWillStop:self];
        }
    }
}

- (void)toggleAccessoriesDidStopCallBack {
    for (id<JDRequestAccessory> accessory in self.requestAccessories) {
        if ([accessory respondsToSelector:@selector(requestDidStop:)]) {
            [accessory requestDidStop:self];
        }
    }
}

@end
