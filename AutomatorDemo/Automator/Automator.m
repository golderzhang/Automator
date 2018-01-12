//
//  Automator.m
//
//  Created by Golder on 2017/2/16.
//  Copyright © 2017年 Golder. All rights reserved.
//

#import "Automator.h"
#import <objc/runtime.h>
#import <os/lock.h>

#pragma mark - CacheBase

static os_unfair_lock_t automator_lock = &OS_UNFAIR_LOCK_INIT;
static CFMutableDictionaryRef automator_cache;

static void automator_cacheValue(const void *key, const void *value) {
    if (!key || !value)
        return;
    
    os_unfair_lock_lock(automator_lock);
    if (!automator_cache) {
        automator_cache = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
    }
    
    CFDictionarySetValue(automator_cache, key, value);
    os_unfair_lock_unlock(automator_lock);
}

static const void *automator_getValue(const void *key) {
    if (!key || !automator_cache)
        return NULL;
    
    os_unfair_lock_lock(automator_lock);
    const void *value = CFDictionaryGetValue(automator_cache, key);
    os_unfair_lock_unlock(automator_lock);
    return value;
}

@implementation Automator

#pragma mark - Cache

+ (void)automatorCacheProperties:(NSArray *)properties forClass:(Class)class {
    automator_cacheValue(class_getName(class), (__bridge_retained CFArrayRef)properties);
}

+ (NSArray *)automatorAllPropertiesForClassFromCache:(Class)class {
    return (__bridge NSArray *)(automator_getValue(class_getName(class)));
}

#pragma mark - Creation

+ (instancetype)automatorWithDictionary:(NSDictionary *)dict {
    return [[[self class] alloc] initWithDictionary:dict];
}

+ (instancetype)automatorWithJSONData:(NSData *)jsonData {
    return [[[self class] alloc] initWithJSONData:jsonData];
}

- (instancetype)initWithDictionary:(NSDictionary<NSString *,id> *)dict {
    if (self = [super init]) {
        [self mapContentsFromDictionary:dict];
    }
    return self;
}

- (instancetype)initWithJSONData:(NSData *)jsonData {
    id dict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:NULL];
    if ([dict isKindOfClass:[NSDictionary class]]) {
        return [self initWithDictionary:dict];
    }
    return [self init];
}

- (void)setValuesForKeysWithDictionary:(NSDictionary<NSString *,id> *)keyedValues {
    [self mapContentsFromDictionary:keyedValues];
}

// 将dict赋值
- (void)mapContentsFromDictionary:(NSDictionary<NSString *,id> *)dict {
    NSArray<NSString *> *allKeysInDict = [dict allKeys];
    NSArray<NSString *> *allProperties = [Automator allPropertyNamesForClass:[self class] recursively:YES];
    
    for (NSString *keyInDict in allKeysInDict) {
        if (![allProperties containsObject:keyInDict]) {
            continue;
        }
        
        id value = [dict valueForKey:keyInDict];
        objc_property_t property = class_getProperty([self class], keyInDict.UTF8String);
        if (property == NULL || [Automator property_isPointType:property])
            continue;
        
        // 获取属性的类型
        Class property_class = [Automator property_getClass:property];
        
        // 处理数组
        if ([value isKindOfClass:[NSArray class]]) {
            if ([property_class isSubclassOfClass:[NSArray class]]) {
                SEL property_arrayClassSelector = NSSelectorFromString([keyInDict stringByAppendingString:@"_class"]);
                if ([self respondsToSelector:property_arrayClassSelector]) {
                    Class property_arrayClass = [self performSelector:property_arrayClassSelector];
                    if (!property_arrayClass || ![property_arrayClass isSubclassOfClass:[Automator class]])
                        continue;
                    NSArray *arrayValue = (NSArray *)value;
                    NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:arrayValue.count];
                    for (int index = 0; index < arrayValue.count; index++) { @autoreleasepool {
                        id objectInArray = arrayValue[index];
                        if ([objectInArray isKindOfClass:[NSDictionary class]]) {
                            id newAutomator = [[property_arrayClass alloc] initWithDictionary:objectInArray];
                            [newArray addObject:newAutomator];
                        } else {
                            [newArray addObject:objectInArray];
                        }
                    } }
                    [self setValue:[newArray copy] forKey:keyInDict];
                } else {
                    [self setValue:value forKey:keyInDict];
                }
            } else if ([Automator property_isIdType:property]) {
                [self setValue:value forKey:keyInDict];
            }
        }
        // 处理字典
        else if ([value isKindOfClass:[NSDictionary class]]) {
            if ([property_class isSubclassOfClass:[Automator class]]) {
                id newValue = [[property_class alloc] initWithDictionary:value];
                [self setValue:newValue forKey:keyInDict];
            } else if ([property_class isSubclassOfClass:[NSDictionary class]]
                       || [Automator property_isIdType:property]) {
                [self setValue:value forKey:keyInDict];
            }
        }
        // 处理数值,此处需注意:当长类型强制转换为短类型时，超出的高位将被截取
        else if ([value isKindOfClass:[NSNumber class]]) {
            if ([property_class isSubclassOfClass:[NSNumber class]]) {
                [self setValue:value forKey:keyInDict];
            } else if ([property_class isSubclassOfClass:[NSString class]]) {
                [self setValue:[NSString stringWithFormat:@"%@", value] forKey:keyInDict];
            } else if ([Automator property_isBasicNumberType:property]) {
                @try {
                    [self setValue:value forKey:keyInDict];
                } @catch (NSException *exception) {
                    NSLog(@"AutomatorException: %@", exception);
                } @finally {
                    continue;
                }
            }
        }
        // 处理字符串
        else if ([value isKindOfClass:[NSString class]]) {
            if ([property_class isSubclassOfClass:[NSString class]]) {
                [self setValue:value forKey:keyInDict];
            }
        }
    }
}

- (NSDictionary *)autoDictionary {
    
    if (([self class] == [Automator class]) || ([self class] == [NSObject class]))
        return nil;
    
    NSArray<NSString *> *allProperty = [Automator allPropertyNamesForClass:[self class] recursively:YES];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:[allProperty count]];
    
    for (NSString *keyInProperty in allProperty) { @autoreleasepool {
        objc_property_t property_t = class_getProperty([self class], keyInProperty.UTF8String);
        if ([Automator property_isPointType:property_t])
            continue;
        
        id value = [self valueForKey:keyInProperty];
        
        if (!value) {
            [dictionary setValue:[NSNull null] forKey:keyInProperty];
            continue;
        }
        
        if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) {
            [dictionary setValue:value forKey:keyInProperty];
        }
        else if ([value isKindOfClass:[Automator class]]) {
            NSDictionary *subDict = [(Automator *)value autoDictionary];
            [dictionary setValue:(subDict)?:[NSNull null] forKey:keyInProperty];
        }
        else if ([value isKindOfClass:[NSArray class]]) {
            NSArray *arrayValue = (NSArray *)value;
            if (arrayValue.count > 0) {
                NSMutableArray *mutable_array = [NSMutableArray arrayWithCapacity:arrayValue.count];
                for (id arrayObj in arrayValue) {
                    
                    if ([arrayObj respondsToSelector:@selector(autoDictionary)]) {
                        [mutable_array addObject:[arrayObj autoDictionary]];
                    }
                    else if ([arrayObj isKindOfClass:[NSString class]] || [arrayObj isKindOfClass:[NSNumber class]]) {
                        [mutable_array addObject:arrayObj];
                    }
                    else {
                        [mutable_array addObject:arrayObj];
                    }
                }
                [dictionary setValue:[mutable_array copy] forKey:keyInProperty];
            } else {
                [dictionary setValue:arrayValue forKey:keyInProperty];
            }
        }
        else {
            [dictionary setValue:(value)?:[NSNull null] forKey:keyInProperty];
        }
    } }
    
    return [dictionary copy];
}

- (NSData *)autoJSONData {
    return [NSJSONSerialization dataWithJSONObject:[self autoDictionary]
                                           options:NSJSONWritingPrettyPrinted
                                             error:NULL];
}

#pragma mark - Util

// 获取当前类所有属性名
+ (NSArray<NSString *> *)allPropertyNamesForClass:(Class)kls {
    return [self allPropertyNamesForClass:kls recursively:NO];
}

// 获取当前类所有属性名, if (recursive==YES) 包含父类
+ (NSArray<NSString *> *)allPropertyNamesForClass:(Class)kls recursively:(BOOL)recursive {
    if (kls == NULL || kls == [NSObject class] || kls == [Automator class])
        return nil;
    
    NSArray *allProperties = [Automator automatorAllPropertiesForClassFromCache:kls];
    if (allProperties)
        return allProperties;
    
    // 使用runtime获取当前类属性
    unsigned int outCount;
    objc_property_t *propertyList = class_copyPropertyList(kls, &outCount);
    NSMutableArray *propertyNames = [NSMutableArray arrayWithCapacity:outCount];
    for (int index = 0; index < outCount; index++) { @autoreleasepool {
        objc_property_t property_t = propertyList[index];
        const char *name = property_getName(property_t);
        NSString *propertyName = [[NSString alloc] initWithCString:name encoding:NSUTF8StringEncoding];
        [propertyNames addObject:propertyName];
    } }
    if (propertyList)
        free(propertyList);
    
    // 是否获取父类属性
    if (recursive) {
        NSArray *superPropertyNames = [self allPropertyNamesForClass:class_getSuperclass(kls) recursively:recursive];
        if (superPropertyNames.count > 0)
            [propertyNames addObjectsFromArray:superPropertyNames];
    }
    
    allProperties = [propertyNames copy];
    [Automator automatorCacheProperties:allProperties forClass:kls];
    
    return allProperties;
}

/*  获取属性声明的类
 *  Example:
 *
 *  id: @
 *  NSObject: @"NSObject"
 */
+ (Class)property_getClass:(objc_property_t)property {
    if (property == NULL)
        return Nil;
    char *attribute_type = property_copyAttributeValue(property, "T");
    if (strncmp(attribute_type, "@", 1) != 0) {
        if (attribute_type)
            free(attribute_type);
        return Nil;
    }
    
    Class kls = Nil;
    if (strlen(attribute_type) > 3) { // not id
        
        char *name = malloc(sizeof(char) * strlen(attribute_type));
        char *src = attribute_type + 2;
        memset(name, 0, strlen(attribute_type));
        size_t len = strlen(src) - 1;
        strncpy(name, src, len);
        *(name + len) = '\0';   // 这个位置之前没插入结束符号，让我跳了一次结实的火坑
        kls = objc_getClass(name);
        if (name)
            free(name);
    }
    if (attribute_type)
        free(attribute_type);
    return kls;
}

// 获取属性的objC类型, 返回值需要free
+ (char *)objCTypeCopyForProperty:(objc_property_t)property {
    if (!property)
        return NULL;
    char *attribute_type = property_copyAttributeValue(property, "T");
    return attribute_type;
}

// 属性是否是id类型
+ (BOOL)property_isIdType:(objc_property_t)property {
    if (property == NULL)
        return NO;
    char *attribute_type = property_copyAttributeValue(property, "T");
    BOOL result = ((strlen(attribute_type) == 1) && (strncmp(attribute_type, "@", 1) == 0));
    if (attribute_type)
        free(attribute_type);
    return result;
}

// 属性是否是C指针类型
+ (BOOL)property_isPointType:(objc_property_t)property {
    if (property == NULL)
        return NO;
    char *attribute_type = property_copyAttributeValue(property, "T");
    BOOL result = ((strlen(attribute_type) == 1) && (strncmp(attribute_type, "*", 1) == 0));
    if (attribute_type)
        free(attribute_type);
    return result;
}

// 属性是否是基础数据类型
+ (BOOL)property_isBasicNumberType:(objc_property_t)property {
    if (property == NULL)
        return NO;
    
    char *attribute_type = property_copyAttributeValue(property, "T");
    if (strlen(attribute_type) > 1)
        return NO;
    
    BOOL isBasicNumberType = NO;
    switch (attribute_type[0]) {
        case 'c':   // char
        case 'C':   // unsigned char
        case 'i':   // int, enum, signed
        case 'I':   // unsigned int
        case 'd':   // double
        case 'f':   // float
        case 'l':   // long
        case 'L':   // unsigned long
        case 's':   // short
        case 'S':   // unsigned short
        case 'q':   // long long
        case 'Q':   // unsigned long long
        case 'B':   // bool
            isBasicNumberType = YES;
            break;
        default:
            break;
    }
    
    if (attribute_type)
        free(attribute_type);
    return isBasicNumberType;
}

// 获取基本数据类型字节长度, eg. length of 'c' = sizeof(char)
+ (int)byteSizeForBasicNumberEncodeType:(const char *)type {
    if (!type)
        return 0;
    switch (type[0]) {
        case 'c':
            return sizeof(char);
        case 'C':
            return sizeof(unsigned char);
        case 'i':
            return sizeof(int);
        case 'I':
            return sizeof(unsigned int);
        case 'd':
            return sizeof(double);
        case 'f':
            return sizeof(float);
        case 'l':
            return sizeof(long);
        case 'L':
            return sizeof(unsigned long);
        case 's':
            return sizeof(short);
        case 'S':
            return sizeof(unsigned short);
        case 'q':
            return sizeof(long long);
        case 'Q':
            return sizeof(unsigned long long);
        case 'B':
            return sizeof(bool);
        default:
            break;
    }
    return 0;
}

@end
