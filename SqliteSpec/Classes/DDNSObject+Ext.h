//
//  DDNSObject+Ext.h
//  XiYuWang
//
//  Created by 李胜书 on 16/5/19.
//  Copyright © 2016年 Ehsy_Sanli. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MJExtension/MJExtension.h>

@interface NSObject (Ext)

+ (instancetype)objectInitWithDictionary:(NSDictionary *)data;

- (void)assginToPropertyWithDictionary: (NSDictionary *) data;

// obj->json
- (NSString *)objConvertToJsonStr;
// json->obj
- (id)jsonStrConvertToObj;

/// 包装部分<MJExtension>
/// 字典数据转模型数组
+ (NSArray *)xxd_objArrFromKeyValues:(id)res;
/// 字典转模型
+ (instancetype)xxd_objFromKeyValue:(id)res;
/// 模型转字典
- (NSDictionary *)xxd_keyValues;
/// 模型数组转字典数组
+ (NSArray *)xxd_keyValuesArrFromObjArr:(NSArray *)res;

@end
