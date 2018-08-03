//
//  DDNSObject+Ext.m
//  XiYuWang
//
//  Created by 李胜书 on 16/5/19.
//  Copyright © 2016年 Ehsy_Sanli. All rights reserved.
//

#import "DDNSObject+Ext.h"

@implementation NSObject (Ext)

+ (instancetype)objectInitWithDictionary:(NSDictionary *)data {
    return [[self alloc] initWithDictionary:data];
}

- (instancetype)initWithDictionary:(NSDictionary *)data {
    {
        self = [self init];
        if (self) {
            [self assginToPropertyWithDictionary:data];
        }
        return self;
    }
}

#pragma mark -- 通过字符串来创建该字符串的Setter方法，并返回
- (SEL) creatSetterWithPropertyName: (NSString *) propertyName{
    //1.首字母大写
    if (propertyName.length > 1) {
        NSString *tempFirstStr = [propertyName substringToIndex:1];
        NSString *tempSecondStr = [propertyName substringFromIndex:1];
        tempFirstStr = [tempFirstStr capitalizedString];
        propertyName = [tempFirstStr stringByAppendingString:tempSecondStr];
    }else {
        propertyName = [propertyName capitalizedString];
    }
    //2.拼接上set关键字
    propertyName = [NSString stringWithFormat:@"set%@:", propertyName];
    //3.返回set方法
    return NSSelectorFromString(propertyName);
}

/************************************************************************
 *把字典赋值给当前实体类的属性
 *参数：字典
 *适用情况：当网络请求的数据的key与实体类的属性相同时可以通过此方法吧字典的Value
 *        赋值给实体类的属性
 ************************************************************************/

- (void)assginToPropertyWithDictionary: (NSDictionary *) data {
    
    if (data == nil) {
        return;
    }
    
    //1.获取字典的key
    NSArray *dicKey = [data allKeys];
    
    //2.循环遍历字典key, 并且动态生成实体类的setter方法，把字典的Value通过setter方法
    //赋值给实体类的属性
    for (int i = 0; i < dicKey.count; i ++) {
        ///2.1 通过getSetterSelWithAttibuteName 方法来获取实体类的set方法
        SEL setSel = [self creatSetterWithPropertyName:dicKey[i]];
        
        if ([self respondsToSelector:setSel]) {
            //2.2 获取字典中key对应的value
            NSObject  *value = [NSString stringWithFormat:@"%@", data[dicKey[i]]];
            //2.3 把值通过setter方法赋值给实体类的属性
            [self performSelectorOnMainThread:setSel
                                   withObject:value
                                waitUntilDone:[NSThread isMainThread]];
        }
        
    }
    
}


/**************************************/
- (id)objConvertToStr {
    if (self == nil) {
        return @"";
    }else if ([self isKindOfClass:[NSString class]]) {
        return (NSString *)self;
    }else if ([self isKindOfClass:[NSNumber class]]) {
        return [((NSNumber *)self) stringValue];
    }
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:self options:NSJSONWritingPrettyPrinted error:nil] encoding:NSUTF8StringEncoding];
}

- (id)jsonStrConvertToObj {
    if (![self isKindOfClass:[NSString class]]) {
        return [NSNull null];
    }
    NSString *json = (NSString *)self;
    return [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
}

+ (NSArray *)xxd_objArrFromKeyValues:(id)res {
    return [self mj_objectArrayWithKeyValuesArray:res];
}
+ (instancetype)xxd_objFromKeyValue:(id)res {
    return [self mj_objectWithKeyValues:res];
}

- (NSDictionary *)xxd_keyValues {
    return self.mj_keyValues;
}

+ (NSArray *)xxd_keyValuesArrFromObjArr:(NSArray *)res {
    return [self mj_keyValuesArrayWithObjectArray:res];
}


@end
