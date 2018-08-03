//
//  DDDBManager.h
//  YZDoctors
//
//  Created by lishengshu on 15-7-29.
//  Copyright (c) 2015年 李胜书. All rights reserved.
//

#import "DDDBSearchHisManager.h"
#import "DDNSObject+Ext.h"
#import <objc/runtime.h>

#import "MJExtension.h"

#define DDWS(weakSelf)  __weak __typeof(&*self)weakSelf = self;
#define DDSS(strongSelf)  __strong __typeof(weakSelf)strongSelf = weakSelf;

@interface DDDBSearchHisManager ()

{
    NSString *dbPath;//数据库存储路径
    NSString *dbCName;//当前db的名字
    FMDatabaseQueue *dbQueue;//使用多线程操作
}

@property (nonatomic,weak) id<DDDBManagerDelegate> delegate;

@end;

@implementation DDDBSearchHisManager

+ (DDDBSearchHisManager *)ShareInstance{
    static DDDBSearchHisManager *sharedDBManagerInstance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        sharedDBManagerInstance = [[self alloc] init];
    });
    return sharedDBManagerInstance;
}
#pragma mark - 创建并打开数据库------------------------|*|*|*|*|*|
- (BOOL)creatDatabase:(NSString *)dbName {
    NSString *docsdir = [NSSearchPathForDirectoriesInDomains( NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    dbPath = [docsdir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite",dbName]];
    dbCName = dbName;
    self.searchHisDB = [FMDatabase databaseWithPath:dbPath];
    //为数据库设置缓存，提高查询效率
    [self.searchHisDB setShouldCacheStatements:YES];
    return [self.searchHisDB open];
}

- (BOOL)isDBReady {
    if(!self.searchHisDB) {
        return NO;
    }
    if (![self.searchHisDB open]) {
        return NO;
    }
    return YES;
}
#pragma mark - 判断表是否存在,不存在则创建表------------------------|*|*|*|*|*|
- (BOOL)isTableExist:(NSString *)tName
             TKeyArr:(NSArray *)keyArr {
    if (![self isDBReady])
        return NO;
    if(![self.searchHisDB tableExists:tName]) {
        __block NSString *tempSql = @"(key INTEGER PRIMARY KEY AUTOINCREMENT";
        [keyArr enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if(idx < keyArr.count - 1) {
                tempSql = [NSString stringWithFormat:@"%@,%@ TEXT",tempSql,obj];
            }else {
                tempSql = [NSString stringWithFormat:@"%@,%@ TEXT)",tempSql,obj];
            }
        }];
        NSString *sql = [NSString stringWithFormat:@"create table %@%@",tName,tempSql];
        return [self.searchHisDB executeUpdate:sql];
    }else {
        return YES;
    }
}

- (BOOL)isTableExist:(NSString *)tName
              TModel:(Class)tableClass {
    NSArray *proArr = [self getAllPropertiesNameArr:[tableClass class]];
    return [self isTableExist:tName
                      TKeyArr:proArr];
}

- (void)isTableExistQueue:(NSString *)tName
                  TKeyArr:(NSArray *)keyArr {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    DDWS(weakSelf)
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        if (db && [db open]) {
            if(![db tableExists:tName]) {
                __block NSString *tempSql = @"(key INTEGER PRIMARY KEY AUTOINCREMENT";
                [keyArr enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if(idx < keyArr.count - 1) {
                        tempSql = [NSString stringWithFormat:@"%@,%@ TEXT",tempSql,obj];
                    }else {
                        tempSql = [NSString stringWithFormat:@"%@,%@ TEXT)",tempSql,obj];
                    }
                }];
                NSString *sql = [NSString stringWithFormat:@"create table %@%@",tName,tempSql];
                BOOL result = [db executeUpdate:sql];
                [weakSelf.delegate tableReadyResult:result TName:tName];
            }else {
                [weakSelf.delegate tableReadyResult:YES TName:tName];
            }
        }else {
            [weakSelf.delegate tableReadyResult:NO TName:tName];
        }
    }];
}

- (void)isTableExistQueue:(NSString *)tName
                   TModel:(Class)tableClass {
    NSArray *proArr = [self getAllPropertiesNameArr:[tableClass class]];
    [self isTableExistQueue:tName
                    TKeyArr:proArr];
}
#pragma mark - 插入列表 或者更新------------------------|*|*|*|*|*|
- (BOOL)insertTableObj:(NSString *)tName
               DataDic:(NSDictionary *)dataDic {
    NSArray *keyArr = [dataDic allKeys];
    if ([self.searchHisDB tableExists:tName]) {
        if (keyArr.count > 0) {
            FMResultSet *searchResult = [self SearchOne:tName
                                              SearchDic:dataDic];
            if (![searchResult next]) {
                NSString *insertsql = [self insertSQL:tName
                                              DataDic:dataDic];
                return [self.searchHisDB executeUpdate:insertsql];
            }
        }
    }
    return NO;
}

- (BOOL)insertTableObj:(NSString *)tName
             DataModel:(Class)tableClass {
    return [self insertTableObj:tName
                        DataDic:tableClass.mj_keyValues];
}

- (BOOL)directInsertTableObj:(NSString *)tName
                     DataDic:(NSDictionary *)dataDic {
    NSArray *keyArr = [dataDic allKeys];
    if ([self.searchHisDB tableExists:tName]) {
        if (keyArr.count > 0) {
            NSString *insertsql = [self insertSQL:tName
                                          DataDic:dataDic];
            return [self.searchHisDB executeUpdate:insertsql];
        }
    }
    return NO;
}

- (BOOL)directInsertTableObj:(NSString *)tName
                   DataModel:(Class)tableClass {
    return [self directInsertTableObj:tName
                              DataDic:tableClass.mj_keyValues];
}

- (void)directInsertTableObjQueue:(NSString *)tName
                          DataDic:(NSDictionary *)dataDic {
    NSArray *keyArr = [dataDic allKeys];
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    DDWS(weakSelf)
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        if ([db tableExists:tName]) {
            if (keyArr.count > 0) {
                DDSS(strongSelf)
                NSString *insertsql = [strongSelf insertSQL:tName
                                                    DataDic:dataDic];
                [weakSelf.delegate tableInsertResult:[db executeUpdate:insertsql]];
            }else {
                [weakSelf.delegate tableInsertResult:NO];
            }
        }else {
            [weakSelf.delegate tableInsertResult:NO];
        }
    }];
}

- (void)directInsertTableObjQueue:(NSString *)tName
                        DataModel:(Class)tableClass {
    [self directInsertTableObjQueue:tName
                            DataDic:tableClass.mj_keyValues];
}

- (void)insertTableObjQueue:(NSString *)tName
                    DataDic:(NSDictionary *)dataDic {
    NSArray *keyArr = [dataDic allKeys];
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    DDWS(weakSelf)
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        if ([db tableExists:tName]) {
            if (keyArr.count > 0) {
                FMResultSet *searchResult;
                DDSS(strongSelf)
                NSString *searchsql = [strongSelf searchSQL:tName
                                                  SearchDic:dataDic];
                if ([db tableExists:tName]) {
                    searchResult = [db executeQuery:searchsql];
                }
                if (![searchResult next]) {
                    NSString *insertsql = [strongSelf insertSQL:tName
                                                        DataDic:dataDic];
                    [weakSelf.delegate tableInsertResult:[db executeUpdate:insertsql]];
                }else {
                    [weakSelf.delegate tableInsertResult:NO];
                }
            }else {
               [weakSelf.delegate tableInsertResult:NO];
            }
        }else {
            [weakSelf.delegate tableInsertResult:NO];
        }
    }];
}

- (void)insertTableObjQueue:(NSString *)tName
                  DataModel:(Class)tableClass {
    [self insertTableObjQueue:tName
                      DataDic:tableClass.mj_keyValues];
}
#pragma mark - 查询数据------------------------|*|*|*|*|*|
//while ([messWithNumber next]) {
//obj.mycontent = [messWithNumber stringForColumn:@"key"];
- (FMResultSet *)SearchOne:(NSString *)tName
                 SearchDic:(NSDictionary *)searchDic {
    FMResultSet *messWithNumber;
    NSString *searchsql = [self searchSQL:tName
                                SearchDic:searchDic];
    if ([self.searchHisDB tableExists:tName]) {
        messWithNumber = [self.searchHisDB executeQuery:searchsql];
    }
    return messWithNumber;
}

- (FMResultSet *)SearchOne:(NSString *)tName
               SearchModel:(Class)searchClass {
    return [self SearchOne:tName
                 SearchDic:searchClass.mj_keyValues];
}

- (void)SearchOneQueue:(NSString *)tName
             SearchDic:(NSDictionary *)searchDic {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    DDWS(weakSelf)
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        FMResultSet *messWithNumber;
        DDSS(strongSelf)
        NSString *searchsql = [strongSelf searchSQL:tName
                                          SearchDic:searchDic];
        if ([db tableExists:tName]) {
            messWithNumber = [db executeQuery:searchsql];
        }
        [weakSelf.delegate tableSearchResult:messWithNumber];
    }];
}

- (void)SearchOneQueue:(NSString *)tName
           SearchModel:(Class)searchClass {
    [self SearchOneQueue:tName
               SearchDic:searchClass.mj_keyValues];
}

- (FMResultSet *)SearchLastNumber:(NSString *)tableName
                           Number:(NSInteger)number {
    FMResultSet *messWithNumber;
    NSString *searchsql = [NSString stringWithFormat:@"SELECT * FROM %@ order by key DESC limit 0,%ld",tableName,number];
    if ([self.searchHisDB tableExists:tableName]) {
        messWithNumber = [self.searchHisDB executeQuery:searchsql];
    }
    return messWithNumber;
}

- (void)SearchLastNumberQueue:(NSString *)tName
                       Number:(NSInteger)number {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    DDWS(weakSelf)
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        FMResultSet *messWithNumber;
        NSString *searchsql = [NSString stringWithFormat:@"SELECT * FROM %@ order by key DESC limit 0,%ld",tName,number];
        if ([db tableExists:tName]) {
            messWithNumber = [db executeQuery:searchsql];
        }
        [weakSelf.delegate tableSearchResult:messWithNumber];
    }];
}

- (FMResultSet *)SearchAll:(NSString *)tName {
    FMResultSet *messWithNumber;
    NSString *searchsql = [NSString stringWithFormat:@"SELECT * FROM %@",tName];
    if ([self.searchHisDB tableExists:tName]) {
        messWithNumber = [self.searchHisDB executeQuery:searchsql];
    }
    return messWithNumber;
}

- (void)SearchAllQueue:(NSString *)tName {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    DDWS(weakSelf)
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        FMResultSet *messWithNumber;
        NSString *searchsql = [NSString stringWithFormat:@"SELECT * FROM %@",tName];
        if ([self.searchHisDB tableExists:tName]) {
            messWithNumber = [self.searchHisDB executeQuery:searchsql];
        }
        [weakSelf.delegate tableSearchResult:messWithNumber];
    }];
}

- (NSMutableArray *)searchAllTableName {
    NSMutableArray *tableMessName = [NSMutableArray array];
    FMResultSet  *tableNameSet;
    NSString *searchsql = [NSString stringWithFormat:@"SELECT NAME FROM sqlite_master WHERE type='table' order by name"];
    tableNameSet = [self.searchHisDB executeQuery:searchsql];
    while ([tableNameSet next]) {
        if (![[tableNameSet stringForColumn:@"name"] isEqualToString:@"sqlite_sequence"]) {
            NSString *tableStringName = [tableNameSet stringForColumn:@"name"];
            [tableMessName addObject:tableStringName];
        }
    }
    return tableMessName;
}

- (void)searchAllTableNameQueue {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    DDWS(weakSelf)
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        NSMutableArray *tableMessName = [NSMutableArray array];
        FMResultSet  *tableNameSet;
        NSString *searchsql = [NSString stringWithFormat:@"SELECT NAME FROM sqlite_master WHERE type='table' order by name"];
        tableNameSet = [db executeQuery:searchsql];
        while ([tableNameSet next]) {
            if (![[tableNameSet stringForColumn:@"name"] isEqualToString:@"sqlite_sequence"]) {
                NSString *tableStringName = [tableNameSet stringForColumn:@"name"];
                [tableMessName addObject:tableStringName];
            }
        }
        [weakSelf.delegate tableSearchResult:tableMessName];
    }];
}
#pragma mark - 删除表------------------------|*|*|*|*|*|
- (BOOL)deleteTable:(NSString *)tName {
    NSString *sqlstr = [NSString stringWithFormat:@"DROP TABLE %@", tName];
    if (![self.searchHisDB executeUpdate:sqlstr]) {
        return NO;
    }
    return YES;
}

- (void)deleteTableQueue:(NSString *)tName {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    DDWS(weakSelf)
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        NSString *sqlstr = [NSString stringWithFormat:@"DROP TABLE %@", tName];
        [weakSelf.delegate tableDeleteResult:[db executeUpdate:sqlstr] TName:tName];
    }];
}
#pragma mark - 根据sqlKey删除数据------------------------|*|*|*|*|*|
- (BOOL)deleTableOjb:(NSString *)tName
           DeleteDic:(NSDictionary *)deleteDic {
    if ([self.searchHisDB tableExists:tName]) {
        NSString *deleteSQL = [self deleteSQL:tName
                                    DeleteDic:deleteDic];
        return [self.searchHisDB executeUpdate:deleteSQL];
    }
    return NO;
}

- (void)deleTableOjbQueue:(NSString *)tName
                DeleteDic:(NSDictionary *)deleteDic {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    DDWS(weakSelf)
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        DDSS(strongSelf)
        NSString *deleteSQL = [strongSelf deleteSQL:tName
                                          DeleteDic:deleteDic];
        [weakSelf.delegate tableDeleteResult:[db executeUpdate:deleteSQL] TName:@""];
    }];
}
#pragma mark - 关闭数据库------------------------|*|*|*|*|*|
- (BOOL)closeDB {
    return [self.searchHisDB close];
}

- (void)closeDBQueue {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    DDWS(weakSelf)
    NSString *dbName = dbCName;
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        [weakSelf.delegate dbCloseResult:[db close] DBName:dbName];
    }];
}
#pragma mark - support methods------------------------|*|*|*|*|*|
/* 获取对象的所有属性名数组 */
- (NSArray *)getAllPropertiesNameArr:(__unsafe_unretained Class)className {
    u_int count;
    objc_property_t *properties  = class_copyPropertyList(className, &count);
    NSMutableArray *propertiesArray = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count ; i++) {
        const char *propertyName = property_getName(properties[i]);
        [propertiesArray addObject:[NSString stringWithUTF8String:propertyName]];
    }
    free(properties);
    return propertiesArray;
}
/**
 根据字典生成插入sql
 
 @param tableName 表名
 @param dataDic 参数字典
 @return 返回生成的sql
 */
- (NSString *)insertSQL:(NSString *)tableName
                DataDic:(NSDictionary *)dataDic {
    NSArray *keyArr = [dataDic allKeys];
    __block NSString *keyString = @"";
    __block NSString *valueString = @"";
    if (keyArr.count == 1) {
        keyString = [NSString stringWithFormat:@"(%@)", keyArr[0]];
        valueString = [NSString stringWithFormat:@"('%@')", [dataDic[keyArr[0]] objConvertToStr]];
    }else {
        [keyArr enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (idx == keyArr.count - 1) {
                keyString = [NSString stringWithFormat:@"%@ %@)",keyString,obj];
                valueString = [NSString stringWithFormat:@"%@'%@')",valueString,[dataDic[obj] objConvertToStr]];
            }else {
                if ([keyString isEqualToString:@""]) {
                    keyString = [NSString stringWithFormat:@"(%@,",obj];
                    valueString = [NSString stringWithFormat:@"('%@',",[dataDic[obj] objConvertToStr]];
                }else {
                    keyString = [NSString stringWithFormat:@"%@ %@,",keyString,obj];
                    valueString = [NSString stringWithFormat:@"%@'%@',",valueString,[dataDic[obj] objConvertToStr]];
                }
            }
        }];
    }
    NSString *insertsql = [NSString stringWithFormat:@"INSERT INTO %@ %@ VALUES %@",tableName,keyString,valueString];
    return insertsql;
}
/**
 根据模型生成插入sql
 
 @param tableName 表名
 @param dataModel 参数模型
 @return 返回生成的sql
 */
- (NSString *)insertSQL:(NSString *)tableName
              DataModel:(Class)dataModel {
    NSDictionary *dataDic = dataModel.mj_keyValues;
    return [self insertSQL:tableName
                   DataDic:dataDic];
}

- (NSString *)searchSQL:(NSString *)tName
              SearchDic:(NSDictionary *)searchDic {
    __block NSString *tempString = @"";
    [searchDic enumerateKeysAndObjectsUsingBlock:^(NSString *key,id value, BOOL * _Nonnull stop) {
        if ([tempString isEqualToString:@""]) {
            tempString = [NSString stringWithFormat:@"%@ = '%@'",key,[value objConvertToStr]];
        }else {
            tempString = [NSString stringWithFormat:@"%@ AND %@ = '%@'",tempString,key,[value objConvertToStr]];
        }
    }];
    NSString *searchSQL;
    if ([tempString isEqualToString:@""]) {
        searchSQL = [NSString stringWithFormat:@"SEARCH * FROM %@",tName];
    }else {
        searchSQL = [NSString stringWithFormat:@"SEARCH * FROM %@ WHERE %@",tName,tempString];
    }
    return searchSQL;
}

/**
 根据字典生成更新sql

 @param tName 表名
 @param dataDic 更新参数字典
 @param searchDic 更新位置查询参数字典
 @return 返回生成的更新sql
 */
- (NSString *)updateSQL:(NSString *)tName
                DataDic:(NSDictionary *)dataDic
              SearchDic:(NSDictionary *)searchDic {
    __block NSString *tempDataStr = @"";
    __block NSString *tempSearchStr = @"";
    [dataDic enumerateKeysAndObjectsUsingBlock:^(NSString *key,id value, BOOL * _Nonnull stop) {
        if ([tempDataStr isEqualToString:@""]) {
            tempDataStr = [NSString stringWithFormat:@"%@ = '%@'",key,[value objConvertToStr]];
        }else {
            tempDataStr = [NSString stringWithFormat:@"%@,%@ = '%@'",tempDataStr,key,[value objConvertToStr]];
        }
    }];
    [searchDic enumerateKeysAndObjectsUsingBlock:^(NSString *key,id value, BOOL * _Nonnull stop) {
        if ([tempSearchStr isEqualToString:@""]) {
            tempSearchStr = [NSString stringWithFormat:@"%@ = '%@'",key,[value objConvertToStr]];
        }else {
            tempSearchStr = [NSString stringWithFormat:@"%@ AND %@ = '%@'",tempSearchStr,key,[value objConvertToStr]];
        }
    }];
    NSString *updatesql;
    if ([tempSearchStr isEqualToString:@""]) {
        updatesql = [NSString stringWithFormat:@"UPDATE %@ set %@",tName,tempDataStr];
    }else {
        updatesql = [NSString stringWithFormat:@"UPDATE %@ set %@ WHERE %@",tName,tempDataStr,tempSearchStr];
    }
    return updatesql;
}

- (NSString *)deleteSQL:(NSString *)tName
              DeleteDic:(NSDictionary *)deleteDic {
    __block NSString *tempDeleteStr = @"";
    [deleteDic enumerateKeysAndObjectsUsingBlock:^(NSString *key,id value, BOOL * _Nonnull stop) {
        if ([tempDeleteStr isEqualToString:@""]) {
            tempDeleteStr = [NSString stringWithFormat:@"%@ = '%@'",key,[value objConvertToStr]];
        }else {
            tempDeleteStr = [NSString stringWithFormat:@"%@ AND %@ = '%@'",tempDeleteStr,key,[value objConvertToStr]];
        }
    }];
    NSString *deleteSQL;
    if ([tempDeleteStr isEqualToString:@""]) {
        deleteSQL = [NSString stringWithFormat:@"DELETE FROM %@",tName];
    }else {
        deleteSQL = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@",tName,tempDeleteStr];
    }
    return deleteSQL;
}

@end
