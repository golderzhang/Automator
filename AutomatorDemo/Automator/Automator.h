//
//  Automator.h
//
//  Created by Golder on 2017/2/16.
//  Copyright © 2017年 Golder. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  Automator是一款自动转换工具
 *  使用功能如下:
 *
 *  1. Dict与Model互相转换
 *  2. JSON与Model互相转换
 */

@interface Automator : NSObject

- (instancetype)initWithDictionary:(NSDictionary<NSString *,id> *)dict;
- (instancetype)initWithJSONData:(NSData *)jsonData;

- (NSDictionary *)autoDictionary;
- (NSData *)autoJSONData;

+ (instancetype)automatorWithDictionary:(NSDictionary<NSString *,id> *)dict;
+ (instancetype)automatorWithJSONData:(NSData *)jsonData;

#pragma mark - Util

// 获取当前类所有属性名
+ (NSArray<NSString *> *)allPropertyNamesForClass:(Class)class;
    
// 获取当前类所有属性名, if (recursive==YES) 包含父类
+ (NSArray<NSString *> *)allPropertyNamesForClass:(Class)class recursively:(BOOL)recursive;

@end
