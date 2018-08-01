//
//  DDDBManager.h
//  YZDoctors
//
//  Created by lishengshu on 15-7-29.
//  Copyright (c) 2015年 李胜书. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FMDB/FMDB.h>

@interface DDDBSearchHisManager : NSObject

+ (DDDBSearchHisManager *)ShareInstance;

@property (nonatomic,strong) FMDatabase *searchHisDB;

#pragma 新的设计将要用到的函数

/**
 创建数据库的函数，利用FMDB的SQL语句创造本地数据库

 @param dbName 本地数据库名
 @return 返回是否成功的bool
 */
- (BOOL)creatDatabase:(NSString *)dbName;
/**
 数据库是否打开

 @return 返回结果
 */
- (BOOL)isDBReady;
/**
 检查本地数据库表是否存在，如不存在，以数组作为键名建表，默认数组第一个元素作为主键

 @param tName 表名
 @param keyArr 数据库参数数组,数组第一个元素是主键名，NSInteger类型自增长
 @return 返回是否成功的bool
 */
- (BOOL)isTableExist:(NSString *)tName
             TKeyArr:(NSArray *)keyArr;

/**
 另起线程检查本地数据库表是否存在，如不存在，以数组作为键名建表，默认数组第一个元素作为主键，NSInteger类型自增长

 @param tName 表名
 @param keyArr 表结构
 @return 返回结果
 */
- (void)isTableExistQueue:(NSString *)tName
                  TKeyArr:(NSArray *)keyArr;

/**
 另起线程检查本地数据库表是否存在，如不存在，以传入的Model模型作为键名建表，默认数组第一个元素作为主键，NSInteger类型自增长

 @param tName 表名
 @param tableClass 模型
 @return 返回结果
 */
- (BOOL)isTableExistQueue:(NSString *)tName
                   TModel:(Class)tableClass;

/**
 根据字典添加数据入库，如果不存在，则新增，如果已存在，更新数据库

 @param tableName 表名
 @param dataDic 数据的字典
 @return 返回结果bool，成功与否
 */
- (BOOL)insertTableObj:(NSString *)tableName
               DataDic:(NSDictionary *)dataDic;
/**
 根据字典直接添加数据入库，不考虑重复情况，另起线程

 @param tableName 表名
 @param dataDic 字典名
 */
- (void)directInsertTableObjQueue:(NSString *)tableName
                          DataDic:(NSDictionary *)dataDic;
/**
 根据字典直接添加数据入库，如果不存在，则新增，如果已存在，更新数据库，另起线程

 @param tableName 表名
 @param dataDic 字典名
 */
- (void)insertTableObjQueue:(NSString *)tableName
                    DataDic:(NSDictionary *)dataDic;
/**
 获取某一表的某一数值的记录

 @param tableName 表名
 @[aram sqlKeyWord sql里的字段名
 @param searchKeyWords 搜索的关键字
 @return 返回的结果
 */
- (FMResultSet *)SearchOne:(NSString *)tableName
                SQLKeyWord:(NSString *)sqlKeyWord
            SearchKeyWords:(NSString *)searchKeyWords;
/**
 返回某一表的最后10行记录

 @param tableName 表名
 @return 返回的记录
 */
- (FMResultSet *)SearchLastTen:(NSString *)tableName;
/**
 搜索并返回某一表的所有字段数值

 @param tableName 要获取的表名
 @return 返回的FMDB的特有格式数组
 */
- (FMResultSet *)SearchAll:(NSString *)tableName;
/**
 获取当前打开的本地数据库的所有表名，返回数组

 @return 返回的表名数组
 */
- (NSMutableArray *)getAllTableName;
/**
 删除表

 @param tableName 删除的表名
 @return 删除结果
 */
- (BOOL)deleteTable:(NSString *)tableName;
/**
 根据数据库某一字段删除某一条记录

 @param tableName 要删除的表名
 @param sqlKey 要删除的字段名
 @param keyWord 要删除的字段的对应值
 @return 返回删除结果
 */
- (BOOL)deleTableOjb:(NSString *)tableName
              SQLKey:(NSString *)sqlKey
             KeyWord:(NSString*)keyWord;
/**
 关闭数据库
 */
- (void)closeDB;



@end
