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

@interface DDDBSearchHisManager ()

{
    NSString *dbPath;//数据库存储路径
    FMDatabaseQueue *dbQueue;//使用多线程操作
}

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
#pragma mark - 创建并打开,创建位置在documents中
- (BOOL)creatDatabase:(NSString *)dbName {
    NSString *docsdir = [NSSearchPathForDirectoriesInDomains( NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    dbPath = [docsdir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite",dbName]];
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
#pragma mark-判断表是否存在,不存在则创建表
- (BOOL)isTableExist:(NSString *)tName
             TKeyArr:(NSArray *)keyArr {
    if (![self isDBReady])
        return NO;
    if(![self.searchHisDB tableExists:tName]) {
        __block NSString *tempSql = @"";
        [keyArr enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (idx == 0) {
                tempSql = [NSString stringWithFormat:@"(%@ INTEGER PRIMARY KEY AUTOINCREMENT",obj];
            }else if(idx < keyArr.count - 1) {
                tempSql = [NSString stringWithFormat:@"%@,%@ TEXT",tempSql,obj];
            }else {
                tempSql = [NSString stringWithFormat:@"%@,%@ TEXT)",tempSql,obj];
            }
        }];
        NSString *sql = [NSString stringWithFormat:@"create table %@%@",tName,tempSql];
        return [self.searchHisDB executeUpdate:sql];
    }else {
        //已经存在
        return YES;
    }
}

- (void)isTableExistQueue:(NSString *)tName
                  TKeyArr:(NSArray *)keyArr {
    if ([self isDBReady]) {
        if (!dbQueue) {
            dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
        }
        [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
            if(![db tableExists:tName]) {
                __block NSString *tempSql = @"";
                [keyArr enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if (idx == 0) {
                        tempSql = [NSString stringWithFormat:@"(%@ INTEGER PRIMARY KEY AUTOINCREMENT",obj];
                    }else if(idx < keyArr.count - 1) {
                        tempSql = [NSString stringWithFormat:@"%@,%@ TEXT",tempSql,obj];
                    }else {
                        tempSql = [NSString stringWithFormat:@"%@,%@ TEXT)",tempSql,obj];
                    }
                }];
                NSString *sql = [NSString stringWithFormat:@"create table %@%@",tName,tempSql];
                    [db executeUpdate:sql];
            }else {
                //已经存在
            }
        }];
    }
}

- (BOOL)isTableExistQueue:(NSString *)tName
                   TModel:(Class)tableClass {
    if (![self isDBReady])
        return NO;
    if(![self.searchHisDB tableExists:tName]) {
        if (!dbQueue) {
            dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
        }
        __block NSString *tempSql = @"";
        NSArray *proArr = [self getAllPropertiesNameArr:[tableClass class]];
        [proArr enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (idx == 0) {
                tempSql = [NSString stringWithFormat:@"(%@ INTEGER PRIMARY KEY AUTOINCREMENT",obj];
            }else if(idx < proArr.count - 1) {
                tempSql = [NSString stringWithFormat:@"%@,%@ TEXT",tempSql,obj];
            }else {
                tempSql = [NSString stringWithFormat:@"%@,%@ TEXT)",tempSql,obj];
            }
        }];
        NSString *sql = [NSString stringWithFormat:@"create table %@%@",tName,tempSql];
        [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
            [db executeUpdate:sql];
        }];
        return YES;
    }else {
        //已经存在
        return YES;
    }
}
#pragma mark-插入列表 或者更新------------------------|*|*|*|*|*|
- (BOOL)insertTableObj:(NSString *)tableName
               DataDic:(NSDictionary *)dataDic {
    NSArray *keyArr = [dataDic allKeys];
    if ([self.searchHisDB tableExists:tableName]) {
        NSString *sqlKey;
        NSString *keyValue;
        if (keyArr.count > 0) {
            sqlKey = keyArr[0];
            keyValue = dataDic[keyArr[0]];
            FMResultSet *searchResult = [self SearchOne:tableName SQLKeyWord:sqlKey SearchKeyWords:keyValue];
            int tempNumber = 0;
            while ([searchResult next]) {
                tempNumber++;
                break;
            }
            if (tempNumber == 0) {
                //不存在重复
                __block NSString *keyString = @"";
                __block NSString *valueString = @"";
                if (keyArr.count == 1) {
                    keyString = [NSString stringWithFormat:@"(%@)", keyArr[0]];
                    valueString = [NSString stringWithFormat:@"('%@')", [dataDic[keyArr[0]] objConvertToJsonStr]];
                } else {
                    
                    [keyArr enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        if (idx == keyArr.count - 1) {
                            keyString = [NSString stringWithFormat:@"%@ %@)",keyString,obj];
                            valueString = [NSString stringWithFormat:@"%@'%@')",valueString,[dataDic[obj] objConvertToJsonStr]];
                        }else {
                            if ([keyString isEqualToString:@""]) {
                                keyString = [NSString stringWithFormat:@"(%@,",obj];
                                valueString = [NSString stringWithFormat:@"('%@',",[dataDic[obj] objConvertToJsonStr]];
                            }else {
                                keyString = [NSString stringWithFormat:@"%@ %@,",keyString,obj];
                                valueString = [NSString stringWithFormat:@"%@'%@',",valueString,[dataDic[obj] objConvertToJsonStr]];
                            }
                        }
                    }];
                }
                NSString *insertsql = [NSString stringWithFormat:@"INSERT INTO %@ %@ VALUES %@",tableName,keyString,valueString];
                if ([self.searchHisDB executeUpdate:insertsql]) {
                    //插入成功
                    return YES;
                }else {
                    return NO;
                }
            }else {
                __block NSString *tempString = @"";
                [keyArr enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if (idx == 0) {
                        tempString = [NSString stringWithFormat:@"%@ = '%@'",obj,[dataDic[obj] objConvertToJsonStr]];
                    }else {
                        tempString = [NSString stringWithFormat:@"%@,%@ = '%@'",tempString,obj,[dataDic[obj] objConvertToJsonStr]];
                    }
                }];
                NSString *updatesql = [NSString stringWithFormat:@"UPDATE %@ set %@",tableName,tempString];
                if ([self.searchHisDB executeUpdate:updatesql]) {
                    return YES;
                }else {
                    return NO;
                }
            }
        }
    }
    return NO;
}

- (void)directInsertTableObjQueue:(NSString *)tableName
                          DataDic:(NSDictionary *)dataDic {
    NSArray *keyArr = [dataDic allKeys];
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    __weak __typeof(&*self)weakSelf = self;
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        if ([db tableExists:tableName]) {
            if (keyArr.count > 0) {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                NSString *insertsql = [strongSelf insertSQL:tableName
                                                    DataDic:dataDic];
                if ([db executeUpdate:insertsql]) {
                    
                }else {
                    
                }
            }
        }
    }];
}

- (void)insertTableObjQueue:(NSString *)tableName
                    DataDic:(NSDictionary *)dataDic {
    NSArray *keyArr = [dataDic allKeys];
    if (!dbQueue) {
        dbQueue = [[FMDatabaseQueue alloc]initWithPath:dbPath];
    }
    __weak __typeof(&*self)weakSelf = self;
    [dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        if ([db tableExists:tableName]) {
            NSString *sqlKey;
            NSString *keyValue;
            if (keyArr.count > 0) {
                sqlKey = keyArr[0];
                keyValue = dataDic[sqlKey];
                FMResultSet *searchResult;
                NSString *searchsql = [NSString stringWithFormat:@"SELECT %@ FROM %@",sqlKey, keyValue];
                if ([db tableExists:tableName]) {
                    searchResult = [db executeQuery:searchsql];
                }
                int tempNumber = 0;
                while ([searchResult next]) {
                    tempNumber++;
                    break;
                }
                if (tempNumber == 0) {
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    NSString *insertsql = [strongSelf insertSQL:tableName
                                                        DataDic:dataDic];
                    [db executeUpdate:insertsql];
                }else {
                    __block NSString *tempString = @"";
                    [keyArr enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        if (idx == 0) {
                            tempString = [NSString stringWithFormat:@"%@ = '%@'",obj,[dataDic[obj] objConvertToJsonStr]];
                        }else {
                            tempString = [NSString stringWithFormat:@"%@,%@ = '%@'",tempString,obj,[dataDic[obj] objConvertToJsonStr]];
                        }
                    }];
                    NSString *updatesql = [NSString stringWithFormat:@"UPDATE %@ set %@",tableName,tempString];
                    [db executeUpdate:updatesql];
                }
            }
        }
    }];
}
#pragma mark - 查询数据
#warning 取材方式
//while ([messWithNumber next]) {
//obj.mycontent = [messWithNumber stringForColumn:@"key"];
- (FMResultSet *)SearchOne:(NSString *)tableName
                SQLKeyWord:(NSString *)sqlKeyWord
            SearchKeyWords:(NSString *)searchKeyWords {
    FMResultSet *messWithNumber;
    NSString *searchsql = [NSString stringWithFormat:@"SELECT %@ FROM %@",sqlKeyWord, tableName];
    
    if ([self.searchHisDB tableExists:tableName]) {
        messWithNumber = [self.searchHisDB executeQuery:searchsql];
    }
    return messWithNumber;
}

- (FMResultSet *)SearchLastTen:(NSString *)tableName {
    FMResultSet *messWithNumber;
    NSString *searchsql=[NSString stringWithFormat:@"SELECT * FROM %@ order by SearchHisID DESC limit 0,10",tableName];
    if ([self.searchHisDB tableExists:tableName]) {
        messWithNumber = [self.searchHisDB executeQuery:searchsql];
    }
    return messWithNumber;
}

- (FMResultSet *)SearchAll:(NSString *)tableName {
    FMResultSet *messWithNumber;
    NSString *searchsql=[NSString stringWithFormat:@"SELECT * FROM %@",tableName];
    if ([self.searchHisDB tableExists:tableName]) {
        messWithNumber = [self.searchHisDB executeQuery:searchsql];
    }
    return messWithNumber;
}
#pragma mark - 获取所有表名
- (NSMutableArray *)getAllTableName {
    NSMutableArray *tableMessName = [NSMutableArray array];
    FMResultSet  *tableNameSet;
    NSString *searchsql=[NSString stringWithFormat:@"SELECT NAME FROM sqlite_master WHERE type='table' order by name"];
    tableNameSet = [self.searchHisDB executeQuery:searchsql];
    while ([tableNameSet next]) {
        if (![[tableNameSet stringForColumn:@"name"] isEqualToString:@"sqlite_sequence"]) {
            NSString *tableStringName = [tableNameSet stringForColumn:@"name"];
            [tableMessName addObject:tableStringName];
        }
    }
    return tableMessName;
}
#pragma mark - 删除表
- (BOOL)deleteTable:(NSString *)tableName {
    NSString *sqlstr = [NSString stringWithFormat:@"DROP TABLE %@", tableName];
    if (![self.searchHisDB executeUpdate:sqlstr]) {
        return NO;
    }
    return YES;
}
#pragma mark - 根据sqlKey删除数据
- (BOOL)deleTableOjb:(NSString *)tableName SQLKey:(NSString *)sqlKey KeyWord:(NSString*)keyWord {
    if ([self.searchHisDB tableExists:tableName]) {
        NSString *insertsql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@='%@'",tableName,sqlKey,keyWord];
        return [self.searchHisDB executeUpdate:insertsql];
    }
    return NO;
}
#pragma mark - 关闭数据库
- (void)closeDB {
    [self.searchHisDB close];
}
#pragma mark - support methods
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
        valueString = [NSString stringWithFormat:@"('%@')", dataDic[keyArr[0]] ];
    } else {
        
        [keyArr enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (idx == keyArr.count - 1) {
                keyString = [NSString stringWithFormat:@"%@ %@)",keyString,obj];
                valueString = [NSString stringWithFormat:@"%@'%@')",valueString,dataDic[obj] ];
            }else {
                if ([keyString isEqualToString:@""]) {
                    keyString = [NSString stringWithFormat:@"(%@,",obj];
                    valueString = [NSString stringWithFormat:@"('%@',",dataDic[obj] ];
                }else {
                    keyString = [NSString stringWithFormat:@"%@ %@,",keyString,obj];
                    valueString = [NSString stringWithFormat:@"%@'%@',",valueString,dataDic[obj] ];
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
    NSArray *keyArr = [dataDic allKeys];
    __block NSString *keyString = @"";
    __block NSString *valueString = @"";
    if (keyArr.count == 1) {
        keyString = [NSString stringWithFormat:@"(%@)", keyArr[0]];
        valueString = [NSString stringWithFormat:@"('%@')", dataDic[keyArr[0]] ];
    }else {
        [keyArr enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (idx == keyArr.count - 1) {
                keyString = [NSString stringWithFormat:@"%@ %@)",keyString,obj];
                valueString = [NSString stringWithFormat:@"%@'%@')",valueString,dataDic[obj] ];
            }else {
                if ([keyString isEqualToString:@""]) {
                    keyString = [NSString stringWithFormat:@"(%@,",obj];
                    valueString = [NSString stringWithFormat:@"('%@',",dataDic[obj] ];
                }else {
                    keyString = [NSString stringWithFormat:@"%@ %@,",keyString,obj];
                    valueString = [NSString stringWithFormat:@"%@'%@',",valueString,dataDic[obj] ];
                }
            }
        }];
    }
    NSString *insertsql = [NSString stringWithFormat:@"INSERT INTO %@ %@ VALUES %@",tableName,keyString,valueString];
    return insertsql;
}

@end
