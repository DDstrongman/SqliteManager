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
    NSString *dbPath;///< 数据库存储路径
    NSString *dbCName;///< 当前db的名字
    FMDatabaseQueue *dbQueue;///< 使用多线程操作
}

@property (nonatomic,weak) id<DDDBManagerDelegate> delegate;

@end;

@implementation DDDBSearchHisManager

struct {
    unsigned int tableReadyResult:1;
    unsigned int tableInsertResult:1;
    unsigned int tableSearchResult:1;
    unsigned int tableUpdateResult:1;
    unsigned int tableDeleteResult:1;
    unsigned int dbCloseResult:1;
} delegateRespondsTo;

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
             tKeyArr:(NSArray *)keyArr {
    if (![self isDBReady])
        return NO;
    if(![self.searchHisDB tableExists:tName]) {
        __block NSString *tempSql = @"(ddkey INTEGER PRIMARY KEY AUTOINCREMENT";
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
              tModel:(Class)tableClass {
    NSArray *proArr = [self getAllPropertiesNameArr:tableClass];
    return [self isTableExist:tName
                      tKeyArr:proArr];
}

- (void)isTableExistQueue:(NSString *)tName
                  tKeyArr:(NSArray *)keyArr {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    DDWS(weakSelf)
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        if (db && [db open]) {
            if(![db tableExists:tName]) {
                __block NSString *tempSql = @"(ddkey INTEGER PRIMARY KEY AUTOINCREMENT";
                [keyArr enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if(idx < keyArr.count - 1) {
                        tempSql = [NSString stringWithFormat:@"%@,%@ TEXT",tempSql,obj];
                    }else {
                        tempSql = [NSString stringWithFormat:@"%@,%@ TEXT)",tempSql,obj];
                    }
                }];
                NSString *sql = [NSString stringWithFormat:@"create table %@%@",tName,tempSql];
                BOOL result = [db executeUpdate:sql];
                if (delegateRespondsTo.tableReadyResult) {
                    [weakSelf.delegate tableReadyResult:result
                                                  tName:tName];
                }
            }else {
                if (delegateRespondsTo.tableReadyResult) {
                    [weakSelf.delegate tableReadyResult:YES
                                                  tName:tName];
                }
            }
        }else {
            if (delegateRespondsTo.tableReadyResult) {
                [weakSelf.delegate tableReadyResult:NO
                                              tName:tName];
            }
        }
    }];
}

- (void)isTableExistQueue:(NSString *)tName
                  tKeyArr:(NSArray *)keyArr
                   result:(void(^)(BOOL result))resultBlock {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        if (db && [db open]) {
            if(![db tableExists:tName]) {
                __block NSString *tempSql = @"(ddkey INTEGER PRIMARY KEY AUTOINCREMENT";
                [keyArr enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if(idx < keyArr.count - 1) {
                        tempSql = [NSString stringWithFormat:@"%@,%@ TEXT",tempSql,obj];
                    }else {
                        tempSql = [NSString stringWithFormat:@"%@,%@ TEXT)",tempSql,obj];
                    }
                }];
                NSString *sql = [NSString stringWithFormat:@"create table %@%@",tName,tempSql];
                BOOL result = [db executeUpdate:sql];
                if (resultBlock) {
                    resultBlock(result);
                }
            }else {
                if (resultBlock) {
                    resultBlock(YES);
                }
            }
        }else {
            if (resultBlock) {
                resultBlock(NO);
            }
        }
    }];
}

- (void)isTableExistQueue:(NSString *)tName
                   tModel:(Class)tableClass {
    NSArray *proArr = [self getAllPropertiesNameArr:tableClass];
    [self isTableExistQueue:tName
                    tKeyArr:proArr];
}

- (void)isTableExistQueue:(NSString *)tName
                   tModel:(Class)tableClass
                   result:(void(^)(BOOL result))resultBlock {
    NSArray *proArr = [self getAllPropertiesNameArr:tableClass];
    [self isTableExistQueue:tName
                    tKeyArr:proArr
                     result:resultBlock];
}
#pragma mark - 插入列表 或者更新------------------------|*|*|*|*|*|
- (BOOL)insertTableObj:(NSString *)tName
               dataDic:(NSDictionary *)dataDic {
    NSArray *keyArr = [dataDic allKeys];
    if ([self.searchHisDB tableExists:tName]) {
        if (keyArr.count > 0) {
            FMResultSet *searchResult = [self searchOne:tName
                                              searchDic:dataDic];
            if (![searchResult next]) {
                NSString *insertsql = [self insertSQL:tName
                                              dataDic:dataDic];
                return [self.searchHisDB executeUpdate:insertsql];
            }
        }
    }
    return NO;
}

- (BOOL)insertTableObj:(NSString *)tName
             dataModel:(NSObject *)dataClass {
    return [self insertTableObj:tName
                        dataDic:dataClass.mj_keyValues];
}

- (BOOL)directInsertTableObj:(NSString *)tName
                     dataDic:(NSDictionary *)dataDic {
    NSArray *keyArr = [dataDic allKeys];
    if ([self.searchHisDB tableExists:tName]) {
        if (keyArr.count > 0) {
            NSString *insertsql = [self insertSQL:tName
                                          dataDic:dataDic];
            return [self.searchHisDB executeUpdate:insertsql];
        }
    }
    return NO;
}

- (BOOL)directInsertTableObj:(NSString *)tName
                   dataModel:(NSObject *)dataClass {
    return [self directInsertTableObj:tName
                              dataDic:dataClass.mj_keyValues];
}

- (void)directInsertTableObjQueue:(NSString *)tName
                          dataDic:(NSDictionary *)dataDic {
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
                                                    dataDic:dataDic];
                if (delegateRespondsTo.tableInsertResult) {
                    [weakSelf.delegate tableInsertResult:[db executeUpdate:insertsql]
                                                   tName:tName
                                                 dataDic:dataDic];
                }else {
                    [db executeUpdate:insertsql];
                }
            }else {
                if (delegateRespondsTo.tableInsertResult) {
                    [weakSelf.delegate tableInsertResult:NO
                                                   tName:tName
                                                 dataDic:dataDic];
                }
            }
        }else {
            if (delegateRespondsTo.tableInsertResult) {
                [weakSelf.delegate tableInsertResult:NO
                                               tName:tName
                                             dataDic:dataDic];
            }
        }
    }];
}

- (void)directInsertTableObjQueue:(NSString *)tName
                          dataDic:(NSDictionary *)dataDic
                           result:(void(^)(BOOL result))resultBlock {
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
                                                    dataDic:dataDic];
                BOOL result = [db executeUpdate:insertsql];
                if (resultBlock) {
                    resultBlock(result);
                }
            }else {
                if (resultBlock) {
                    resultBlock(NO);
                }
            }
        }else {
            if (resultBlock) {
                resultBlock(NO);
            }
        }
    }];
}

- (void)directInsertTableObjQueue:(NSString *)tName
                        dataModel:(NSObject *)dataClass {
    [self directInsertTableObjQueue:tName
                            dataDic:dataClass.mj_keyValues];
}

- (void)directInsertTableObjQueue:(NSString *)tName
                        dataModel:(NSObject *)dataClass
                           result:(void(^)(BOOL result))resultBlock {
    [self directInsertTableObjQueue:tName
                            dataDic:dataClass.mj_keyValues
                             result:resultBlock];
}

- (void)insertTableObjQueue:(NSString *)tName
                    dataDic:(NSDictionary *)dataDic {
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
                                                  searchDic:dataDic];
                if ([db tableExists:tName]) {
                    searchResult = [db executeQuery:searchsql];
                }
                if (![searchResult next]) {
                    NSString *insertsql = [strongSelf insertSQL:tName
                                                        dataDic:dataDic];
                    if (delegateRespondsTo.tableInsertResult) {
                        [weakSelf.delegate tableInsertResult:[db executeUpdate:insertsql]
                                                       tName:tName
                                                     dataDic:dataDic];
                    }else {
                        [db executeUpdate:insertsql];
                    }
                }else {
                    if (delegateRespondsTo.tableInsertResult) {
                        [weakSelf.delegate tableInsertResult:NO
                                                       tName:tName
                                                     dataDic:dataDic];
                    }
                }
            }else {
                if (delegateRespondsTo.tableInsertResult) {
                    [weakSelf.delegate tableInsertResult:NO
                                                   tName:tName
                                                 dataDic:dataDic];
                }
            }
        }else {
            if (delegateRespondsTo.tableInsertResult) {
                [weakSelf.delegate tableInsertResult:NO
                                               tName:tName
                                             dataDic:dataDic];
            }
        }
    }];
}

- (void)insertTableObjQueue:(NSString *)tName
                    dataDic:(NSDictionary *)dataDic
                     result:(void(^)(BOOL result))resultBlock {
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
                                                  searchDic:dataDic];
                if ([db tableExists:tName]) {
                    searchResult = [db executeQuery:searchsql];
                }
                if (![searchResult next]) {
                    NSString *insertsql = [strongSelf insertSQL:tName
                                                        dataDic:dataDic];
                    BOOL result = [db executeUpdate:insertsql];
                    if (resultBlock) {
                        resultBlock(result);
                    }
                }else {
                    if (resultBlock) {
                        resultBlock(NO);
                    }
                }
            }else {
                if (resultBlock) {
                    resultBlock(NO);
                }
            }
        }else {
            if (resultBlock) {
                resultBlock(NO);
            }
        }
    }];
}

- (void)insertTableObjQueue:(NSString *)tName
                  dataModel:(NSObject *)dataClass {
    [self insertTableObjQueue:tName
                      dataDic:dataClass.mj_keyValues];
}

- (void)insertTableObjQueue:(NSString *)tName
                  dataModel:(NSObject *)dataClass
                     result:(void(^)(BOOL result))resultBlock {
    [self insertTableObjQueue:tName
                      dataDic:dataClass.mj_keyValues
                       result:resultBlock];
}
#pragma mark - 查询数据------------------------|*|*|*|*|*|
//while ([messWithNumber next]) {
//obj.mycontent = [messWithNumber stringForColumn:@"key"];
- (FMResultSet *)searchOne:(NSString *)tName
                 searchDic:(NSDictionary *)searchDic {
    FMResultSet *messWithNumber;
    NSString *searchsql = [self searchSQL:tName
                                searchDic:searchDic];
    if ([self.searchHisDB tableExists:tName]) {
        messWithNumber = [self.searchHisDB executeQuery:searchsql];
    }
    return messWithNumber;
}

- (FMResultSet *)searchOne:(NSString *)tName
               searchModel:(NSObject *)searchClass {
    return [self searchOne:tName
                 searchDic:searchClass.mj_keyValues];
}

- (void)searchOneQueue:(NSString *)tName
             searchDic:(NSDictionary *)searchDic {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    DDWS(weakSelf)
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        FMResultSet *messWithNumber;
        DDSS(strongSelf)
        NSString *searchsql = [strongSelf searchSQL:tName
                                          searchDic:searchDic];
        if ([db tableExists:tName]) {
            messWithNumber = [db executeQuery:searchsql];
        }
        if (delegateRespondsTo.tableSearchResult) {
            [weakSelf.delegate tableSearchResult:messWithNumber
                                           tName:tName
                                         dataDic:searchDic];
        }
    }];
}

- (void)searchOneQueue:(NSString *)tName
             searchDic:(NSDictionary *)searchDic
                result:(void(^)(id result))resultBlock {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    DDWS(weakSelf)
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        FMResultSet *messWithNumber;
        DDSS(strongSelf)
        NSString *searchsql = [strongSelf searchSQL:tName
                                          searchDic:searchDic];
        if ([db tableExists:tName]) {
            messWithNumber = [db executeQuery:searchsql];
        }
        if (resultBlock) {
            resultBlock(messWithNumber);
        }
    }];
}

- (void)searchOneQueue:(NSString *)tName
           searchModel:(NSObject *)searchClass {
    [self searchOneQueue:tName
               searchDic:searchClass.mj_keyValues];
}

- (void)searchOneQueue:(NSString *)tName
           searchModel:(NSObject *)searchClass
                result:(void (^)(id))resultBlock{
    [self searchOneQueue:tName
               searchDic:searchClass.mj_keyValues
                  result:resultBlock];
}

- (FMResultSet *)searchLastNumber:(NSString *)tableName
                           number:(long)number {
    FMResultSet *messWithNumber;
    NSString *searchsql = [NSString stringWithFormat:@"SELECT * FROM %@ order by ddkey DESC limit 0,%ld",tableName,number];
    if ([self.searchHisDB tableExists:tableName]) {
        messWithNumber = [self.searchHisDB executeQuery:searchsql];
    }
    return messWithNumber;
}

- (void)searchLastNumberQueue:(NSString *)tName
                       number:(long)number {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    DDWS(weakSelf)
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        FMResultSet *messWithNumber;
        NSString *searchsql = [NSString stringWithFormat:@"SELECT * FROM %@ order by ddkey DESC limit 0,%ld",tName,number];
        if ([db tableExists:tName]) {
            messWithNumber = [db executeQuery:searchsql];
        }
        if (delegateRespondsTo.tableSearchResult) {
            [weakSelf.delegate tableSearchResult:messWithNumber
                                           tName:nil
                                         dataDic:nil];
        }
    }];
}

- (void)searchLastNumberQueue:(NSString *)tName
                       number:(long)number
                       result:(void(^)(id result))resultBlock {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        FMResultSet *messWithNumber;
        NSString *searchsql = [NSString stringWithFormat:@"SELECT * FROM %@ order by ddkey DESC limit 0,%ld",tName,number];
        if ([db tableExists:tName]) {
            messWithNumber = [db executeQuery:searchsql];
        }
        if (resultBlock) {
            resultBlock(messWithNumber);
        }
    }];
}

- (FMResultSet *)searchAll:(NSString *)tName {
    FMResultSet *messWithNumber;
    NSString *searchsql = [NSString stringWithFormat:@"SELECT * FROM %@",tName];
    if ([self.searchHisDB tableExists:tName]) {
        messWithNumber = [self.searchHisDB executeQuery:searchsql];
    }
    return messWithNumber;
}

- (void)searchAllQueue:(NSString *)tName {
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
        if (delegateRespondsTo.tableSearchResult) {
            [weakSelf.delegate tableSearchResult:messWithNumber
                                           tName:nil
                                         dataDic:nil];
        }
    }];
}

- (void)searchAllQueue:(NSString *)tName
                result:(void(^)(FMResultSet *result))resultBlock {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    DDWS(weakSelf)
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        FMResultSet *messWithNumber;
        NSString *searchsql = [NSString stringWithFormat:@"SELECT * FROM %@",tName];
        if ([weakSelf.searchHisDB tableExists:tName]) {
            messWithNumber = [weakSelf.searchHisDB executeQuery:searchsql];
        }
        if (resultBlock) {
            resultBlock(messWithNumber);
        }
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
        if (delegateRespondsTo.tableSearchResult) {
            [weakSelf.delegate tableSearchResult:tableMessName
                                           tName:nil
                                         dataDic:nil];
        }
    }];
}

- (void)searchAllTableNameQueue:(void(^)(NSMutableArray *result))resultBlock {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
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
        if (resultBlock) {
            resultBlock(tableMessName);
        }
    }];
}
#pragma mark - 更新表------------------------|*|*|*|*|*|
- (BOOL)updateTableObj:(NSString *)tName
             searchDic:(NSDictionary *)searchDic
               dataDic:(NSDictionary *)dataDic {
    BOOL updateResult = NO;
    NSString *updateSql = [self updateSQL:tName
                                searchDic:searchDic
                                  dataDic:dataDic];
    if ([self.searchHisDB tableExists:tName]) {
        updateResult = [self.searchHisDB executeUpdate:updateSql];
    }
    return updateResult;
}

- (BOOL)updateTableObj:(NSString *)tName
           searchModel:(NSObject *)searchClass
             dataModel:(NSObject *)dataClass {
    return [self updateTableObj:tName
                      searchDic:searchClass.mj_keyValues
                        dataDic:dataClass.mj_keyValues];
}

- (void)updateTableObjQueue:(NSString *)tName
                  searchDic:(NSDictionary *)searchDic
                    dataDic:(NSDictionary *)dataDic {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    DDWS(weakSelf)
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        DDSS(strongSelf)
        NSString *updateSql = [strongSelf updateSQL:tName
                                          searchDic:searchDic
                                            dataDic:dataDic];
        if ([db tableExists:tName]) {
            if (delegateRespondsTo.tableUpdateResult) {
                [weakSelf.delegate tableUpdateResult:[db executeUpdate:updateSql]
                                               tName:tName
                                              search:searchDic
                                             dataDic:dataDic];
            }else {
                [db executeUpdate:updateSql];
            }
        }else {
            if (delegateRespondsTo.tableUpdateResult) {
                [weakSelf.delegate tableUpdateResult:NO
                                               tName:tName
                                              search:searchDic
                                             dataDic:dataDic];
            }
        }
    }];
}

- (void)updateTableObjQueue:(NSString *)tName
                  searchDic:(NSDictionary *)searchDic
                    dataDic:(NSDictionary *)dataDic
                     result:(void(^)(BOOL result))resultBlock {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    DDWS(weakSelf)
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        DDSS(strongSelf)
        NSString *updateSql = [strongSelf updateSQL:tName
                                          searchDic:searchDic
                                            dataDic:dataDic];
        if ([db tableExists:tName]) {
            BOOL result = [db executeUpdate:updateSql];
            if (resultBlock) {
                resultBlock(result);
            }
        } else {
            if (resultBlock) {
                resultBlock(NO);
            }
        }
    }];
}

- (void)updateTableObjQueue:(NSString *)tName
                searchModel:(NSObject *)searchClass
                  dataModel:(NSObject *)dataClass {
    [self updateTableObjQueue:tName
                    searchDic:searchClass.mj_keyValues
                      dataDic:dataClass.mj_keyValues];
}

- (void)updateTableObjQueue:(NSString *)tName
                searchModel:(NSObject *)searchClass
                  dataModel:(NSObject *)dataClass
                     result:(void(^)(BOOL result))resultBlock {
    [self updateTableObjQueue:tName
                    searchDic:searchClass.mj_keyValues
                      dataDic:dataClass.mj_keyValues
                       result:resultBlock];
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
        if (delegateRespondsTo.tableDeleteResult) {
            [weakSelf.delegate tableDeleteResult:[db executeUpdate:sqlstr]
                                           tName:tName];
        }else {
            [db executeUpdate:sqlstr];
        }
    }];
}

- (void)deleteTableQueue:(NSString *)tName
                  result:(void(^)(BOOL result))resultBlock {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        NSString *sqlstr = [NSString stringWithFormat:@"DROP TABLE %@", tName];
        BOOL result = [db executeUpdate:sqlstr];
        if (resultBlock) {
            resultBlock(result);
        }
    }];
}
#pragma mark - 根据sqlKey删除数据------------------------|*|*|*|*|*|
- (BOOL)deleTableOjb:(NSString *)tName
           deleteDic:(NSDictionary *)deleteDic {
    if ([self.searchHisDB tableExists:tName]) {
        NSString *deleteSQL = [self deleteSQL:tName
                                    deleteDic:deleteDic];
        return [self.searchHisDB executeUpdate:deleteSQL];
    }
    return NO;
}

- (void)deleTableOjbQueue:(NSString *)tName
                deleteDic:(NSDictionary *)deleteDic {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    DDWS(weakSelf)
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        DDSS(strongSelf)
        NSString *deleteSQL = [strongSelf deleteSQL:tName
                                          deleteDic:deleteDic];
        if (delegateRespondsTo.tableDeleteResult) {
            [weakSelf.delegate tableDeleteResult:[db executeUpdate:deleteSQL]
                                           tName:tName];
        }else {
            [db executeUpdate:deleteSQL];
        }
    }];
}

- (void)deleTableOjbQueue:(NSString *)tName
                deleteDic:(NSDictionary *)deleteDic
                   result:(void(^)(BOOL result))resultBlock {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    DDWS(weakSelf)
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        DDSS(strongSelf)
        NSString *deleteSQL = [strongSelf deleteSQL:tName
                                          deleteDic:deleteDic];
        BOOL result = [db executeUpdate:deleteSQL];
        if (resultBlock) {
            resultBlock(result);
        }
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
        if (delegateRespondsTo.dbCloseResult) {
            [weakSelf.delegate dbCloseResult:[db close]
                                      dbName:dbName];
        }else {
            [db close];
        }
    }];
}

- (void)closeDBQueue:(void(^)(BOOL result))resultBlock {
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        BOOL result = [db close];
        if (resultBlock) {
            resultBlock(result);
        }
    }];
}
#pragma mark - lazy loading统一检查是否响应delegate
- (void)setDelegate:(id<DDDBManagerDelegate>)delegate {
    if (_delegate != delegate) {
        _delegate = delegate;
        delegateRespondsTo.tableReadyResult = [delegate respondsToSelector:@selector(tableReadyResult:tName:)];
        delegateRespondsTo.tableDeleteResult = [delegate respondsToSelector:@selector(tableDeleteResult:tName:)];
        delegateRespondsTo.tableInsertResult = [delegate respondsToSelector:@selector(tableInsertResult:tName:dataDic:)];
        delegateRespondsTo.tableSearchResult = [delegate respondsToSelector:@selector(tableSearchResult:tName:dataDic:)];
        delegateRespondsTo.tableUpdateResult = [delegate respondsToSelector:@selector(tableUpdateResult:tName:search:dataDic:)];
        delegateRespondsTo.dbCloseResult = [delegate respondsToSelector:@selector(dbCloseResult:dbName:)];
    }
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
                dataDic:(NSDictionary *)dataDic {
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
              dataModel:(Class)dataModel {
    NSDictionary *dataDic = dataModel.mj_keyValues;
    return [self insertSQL:tableName
                   dataDic:dataDic];
}

- (NSString *)searchSQL:(NSString *)tName
              searchDic:(NSDictionary *)searchDic {
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
        searchSQL = [NSString stringWithFormat:@"SELECT * FROM %@",tName];
    }else {
        searchSQL = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@",tName,tempString];
    }
    return searchSQL;
}

/**
 根据字典生成更新sql

 @param tName 表名
 @param searchDic 更新位置查询参数字典
 @param dataDic 更新参数字典
 @return 返回生成的更新sql
 */
- (NSString *)updateSQL:(NSString *)tName
              searchDic:(NSDictionary *)searchDic
                dataDic:(NSDictionary *)dataDic {
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
              deleteDic:(NSDictionary *)deleteDic {
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
