//
//  DDDBManager.h
//  YZDoctors
//
//  Created by lishengshu on 15-7-29.
//  Copyright (c) 2015年 李胜书. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FMDB/FMDB.h>

@protocol DDDBManagerDelegate <NSObject>

@optional
/**
 异步表创建或直接使用查询的结果

 @param result 异步的表结果
 @param tName 此结果的表名
 */
- (void)tableReadyResult:(BOOL)result
                   TName:(NSString *)tName;
/**
 异步表插入的结果

 @param result 插入结果
 @param tName 表名
 @param dataDic 数据的字典
 */
- (void)tableInsertResult:(BOOL)result
                    TName:(NSString *)tName
                  DataDic:(NSDictionary *)dataDic;
/**
 异步搜索返回结果

 @param result 返回搜索结果
 @param tName 表名
 @param dataDic 数据的字典
 */
- (void)tableSearchResult:(id)result
                    TName:(NSString *)tName
                  DataDic:(NSDictionary *)dataDic;
/**
 异步搜索返回结果
 
 @param result 返回更新结果
 @param tName 表名
 @param search 更新数据的条件字典或条件类
 @param data 更新数据的字典或类
 */
- (void)tableUpdateResult:(BOOL)result
                    TName:(NSString *)tName
                   Search:(id)search
                  DataDic:(id)data;
/**
 异步删除返回表结果
 
 @param result 返回删除表结果
 @param tName 删除的表名
 */
- (void)tableDeleteResult:(BOOL)result
                    TName:(NSString *)tName;
/**
 异步关闭数据库结果

 @param result 关闭数据库的结果
 @param dbName 关闭的db的名字
 */
- (void)dbCloseResult:(BOOL)result
               DBName:(NSString *)dbName;

@end;

@interface DDDBSearchHisManager : NSObject

/**
 单实例化

 @return 返回生成的单实例
 */
+ (DDDBSearchHisManager *)ShareInstance;

@property (nonatomic,strong) FMDatabase *searchHisDB;

#pragma mark - 数据库创建,表创建------------------------|*|*|*|*|*|
/**
 创建数据库的函数，利用FMDB的SQL语句创造本地数据库

 @param dbName 本地数据库名
 @return 返回是否成功的bool
 */
- (BOOL)creatDatabase:(NSString *)dbName;
/**
 查询数据库是否打开

 @return 返回结果
 */
- (BOOL)isDBReady;
/**
 检查本地数据库表是否存在，如不存在，以数组作为键名建表，默认主键名为key，NSInteger类型自增长

 @param tName 表名
 @param keyArr 数据库参数数组
 @return 返回是否成功的bool
 */
- (BOOL)isTableExist:(NSString *)tName
             TKeyArr:(NSArray *)keyArr;
/**
 检查本地数据库表是否存在，如不存在，以数组作为键名建表，默认主键名为key，NSInteger类型自增长
 
 @param tName 表名
 @param tableClass 数据库参数模型
 @return 返回是否成功的bool
 */
- (BOOL)isTableExist:(NSString *)tName
              TModel:(Class)tableClass;

/**
 另起线程检查本地数据库表是否存在，如不存在，以数组作为键名建表，默认主键名为key，NSInteger类型自增长，通过delegate通知异步处理结果

 @param tName 表名
 @param keyArr 表结构
 */
- (void)isTableExistQueue:(NSString *)tName
                  TKeyArr:(NSArray *)keyArr;

/**
 另起线程检查本地数据库表是否存在，如不存在，以传入的Model模型作为键名建表，默认主键名为key，NSInteger类型自增长，通过delegate通知异步处理结果

 @param tName 表名
 @param tableClass 模型
 */
- (void)isTableExistQueue:(NSString *)tName
                   TModel:(Class)tableClass;
#pragma mark - 数据库插入更新操作------------------------|*|*|*|*|*|
/**
 根据字典添加数据入库，如果不存在，则新增，如果已存在，返回no

 @param tName 表名
 @param dataDic 数据的字典
 @return 返回结果bool，成功与否
 */
- (BOOL)insertTableObj:(NSString *)tName
               DataDic:(NSDictionary *)dataDic;
/**
 根据字典添加数据入库，如果不存在，则新增，如果已存在，返回no
 
 @param tName 表名
 @param dataClass 数据的模型类
 @return 返回结果bool，成功与否
 */
- (BOOL)insertTableObj:(NSString *)tName
             DataModel:(Class)dataClass;
/**
 根据字典添加数据入库，直接新增，不管重复
 
 @param tName 表名
 @param dataDic 数据的字典
 @return 返回结果bool，成功与否
 */
- (BOOL)directInsertTableObj:(NSString *)tName
                     DataDic:(NSDictionary *)dataDic;
/**
 根据模型添加数据入库，直接新增，不管重复
 
 @param tName 表名
 @param dataClass 数据的模型类
 @return 返回结果bool，成功与否
 */
- (BOOL)directInsertTableObj:(NSString *)tName
                   DataModel:(Class)dataClass;
/**
 另起线程根据字典直接添加数据入库，不考虑重复情况，delegate通知异步处理结果

 @param tName 表名
 @param dataDic 字典名
 */
- (void)directInsertTableObjQueue:(NSString *)tName
                          DataDic:(NSDictionary *)dataDic;
/**
 另起线程根据字典直接添加数据入库，不考虑重复情况，delegate通知异步处理结果
 
 @param tName 表名
 @param dataClass 数据的模型类
 */
- (void)directInsertTableObjQueue:(NSString *)tName
                        DataModel:(Class)dataClass;
/**
 根据字典直接添加数据入库，如果不存在，则新增，如果已存在，delegate返回失败，另起线程

 @param tName 表名
 @param dataDic 字典名
 */
- (void)insertTableObjQueue:(NSString *)tName
                    DataDic:(NSDictionary *)dataDic;
/**
 另起线程根据字典添加数据入库，重复情况delegate返回失败，delegate通知异步处理结果
 
 @param tName 表名
 @param dataClass 数据的模型类
 */
- (void)insertTableObjQueue:(NSString *)tName
                  DataModel:(Class)dataClass;
#pragma mark - 数据库查询操作------------------------|*|*|*|*|*|
/**
 通过字典获取某一表的某一项的记录

 @param tName 表名
 @param searchDic 搜索的条件字典
 @return 返回
 */
- (FMResultSet *)SearchOne:(NSString *)tName
                 SearchDic:(NSDictionary *)searchDic;
/**
 通过模型获取某一表的某一项的记录
 
 @param tName 表名
 @param searchClass 搜索的条件model
 @return 返回
 */
- (FMResultSet *)SearchOne:(NSString *)tName
               SearchModel:(Class)searchClass;
/**
 异步获取某一表的某一项的记录，delegate通知返回
 
 @param tName 表名
 @param searchDic 搜索的条件字典
 */
- (void)SearchOneQueue:(NSString *)tName
             SearchDic:(NSDictionary *)searchDic;
/**
 通过模型获取某一表的某一项的记录，delegate通知返回
 
 @param tName 表名
 @param searchClass 搜索的条件model
 */
- (void)SearchOneQueue:(NSString *)tName
           SearchModel:(Class)searchClass;
/**
 返回某一表的最后number行记录

 @param tName 表名
 @param number 最后多少行
 @return 返回的记录
 */
- (FMResultSet *)SearchLastNumber:(NSString *)tName
                           Number:(long)number;
/**
 异步返回某一表的最后number行记录,delegate返回结果
 
 @param tName 表名
 @param number 最后多少行
 */
- (void)SearchLastNumberQueue:(NSString *)tName
                       Number:(long)number;
/**
 搜索并返回某一表的所有字段数值

 @param tName 要获取的表名
 @return 返回的FMDB的特有格式数组
 */
- (FMResultSet *)SearchAll:(NSString *)tName;
/**
 异步搜索并返回某一表的所有字段数值,delegate返回结果
 
 @param tName 要获取的表名
 */
- (void)SearchAllQueue:(NSString *)tName;
/**
 获取当前打开的本地数据库的所有表名，返回数组

 @return 返回的表名数组
 */
- (NSMutableArray *)SearchAllTableName;
/**
 异步获取当前打开的本地数据库的所有表名,delegate返回结果
 */
- (void)SearchAllTableNameQueue;
#pragma mark - 数据库更新操作------------------------|*|*|*|*|*|
/**
 根据搜索字典更新数据库，如果不存在，返回no
 
 @param tName 表名
 @param searchDic 更新数据的条件字典
 @param dataDic 数据的字典
 @return 返回结果bool，成功与否
 */
- (BOOL)updateTableObj:(NSString *)tName
             SearchDic:(NSDictionary *)searchDic
               DataDic:(NSDictionary *)dataDic;
/**
 根据搜索模型更新数据库，如果不存在，返回no
 
 @param tName 表名
 @param searchClass 更新数据的条件模型类
 @param dataClass 数据的模型类
 @return 返回结果bool，成功与否
 */
- (BOOL)updateTableObj:(NSString *)tName
           SearchModel:(Class)searchClass
             DataModel:(Class)dataClass;
/**
 异步根据搜索字典更新数据，如果不存在，返回no，通过delegate返回结果
 
 @param tName 表名
 @param searchDic 更新数据的条件字典
 @param dataDic 数据的模型类
 */
- (void)updateTableObjQueue:(NSString *)tName
                  SearchDic:(NSDictionary *)searchDic
                    DataDic:(NSDictionary *)dataDic;
/**
 异步根据搜索模型更新数据入库，如果不存在，返回no，通过delegate返回结果
 
 @param tName 表名
 @param searchClass 更新数据的条件模型类
 @param dataClass 数据的模型类
 */
- (void)updateTableObjQueue:(NSString *)tName
                SearchModel:(Class)searchClass
                  DataModel:(Class)dataClass;
#pragma mark - 数据库删除操作------------------------|*|*|*|*|*|
/**
 删除表

 @param tName 删除的表名
 @return 删除结果
 */
- (BOOL)deleteTable:(NSString *)tName;
/**
 异步删除表，delegate返回结果
 
 @param tName 删除的表名
 */
- (void)deleteTableQueue:(NSString *)tName;
/**
 根据数据库某一字段删除某一条记录

 @param tName 要删除的表名
 @param deleteDic 要删除的条件字典
 @return 返回删除结果
 */
- (BOOL)deleTableOjb:(NSString *)tName
           DeleteDic:(NSDictionary *)deleteDic;
/**
 根据数据库某一字段异步删除某一条记录，delegate返回结果
 
 @param tName 要删除的表名
 @param deleteDic 要删除的条件字典
 */
- (void)deleTableOjbQueue:(NSString *)tName
                DeleteDic:(NSDictionary *)deleteDic;
#pragma mark - 关闭数据库------------------------|*|*|*|*|*|
/**
 关闭数据库
 */
- (BOOL)closeDB;
/**
 异步关闭数据库，通过delegate返回关闭结果
 */
- (void)closeDBQueue;



@end
