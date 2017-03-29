//
//  DBManager.h
//  YZDoctors
//
//  Created by lishengshu on 15-7-29.
//  Copyright (c) 2015年 李胜书. All rights reserved.
//

#import "DBSearchHisManager.h"
#import <FMDB/FMDB.h>
#import "NSObject+Ext.h"

@implementation DBSearchHisManager

+ (DBSearchHisManager *)ShareInstance{
    static DBSearchHisManager *sharedDBManagerInstance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        sharedDBManagerInstance = [[self alloc] init];
    });
    return sharedDBManagerInstance;
}
#pragma mark - 创建并打开,创建位置在documents中
- (BOOL)creatDatabase:(NSString *)dbName {
    NSString *docsdir = [NSSearchPathForDirectoriesInDomains( NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *dbPath = [docsdir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite",dbName]];
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
- (BOOL)isTableExist:(NSString *)tName TKeyArr:(NSArray *)keyArr {
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
#pragma mark-插入列表 或者更新------------------------|*|*|*|*|*|
- (BOOL)addTableObj:(NSString *)tableName DataDic:(NSDictionary *)dataDic {
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
//                NSString *updatesql = [NSString stringWithFormat:@"UPDATE %@ set %@ where %@ = '%@'",tableName,tempString,sqlKey,keyValue];
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
#pragma mark - 查询数据
#warning 取材方式
//while ([messWithNumber next]) {
//obj.mycontent = [messWithNumber stringForColumn:@"key"];
- (FMResultSet *)SearchOne:(NSString *)tableName SQLKeyWord:(NSString *)sqlKeyWord SearchKeyWords:(NSString *)searchKeyWords {
    FMResultSet *messWithNumber;
//    NSString *searchsql = [NSString stringWithFormat:@"SELECT * FROM %@ where %@ = '%@'",tableName,sqlKeyWord,searchKeyWords];
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

//#pragma mark - 查询所有
//- (NSDictionary *)queryAllQuickMenuWithTableName:(NSString *)tableName {
//    FMResultSet *result = [self SearchAll:tableName];
//    NSMutableDictionary *dic = @{}.mutableCopy;
//    while (result.next) {
//        
//        NSString *titleStr = [result stringForColumn:quickHelpTitle];
//        [dic setValue:[titleStr jsonStrConvertToObj] forKey:quickHelpTitle];
//        
//        NSString *contentStr = [result stringForColumn:quickHelpContent];
//        [dic setValue:[contentStr jsonStrConvertToObj] forKey:quickHelpContent];
//        
//        NSString *myQuickMenuStr = [result stringForColumn:myQuickMenu];
//        [dic setValue:[myQuickMenuStr jsonStrConvertToObj] forKey:myQuickMenu];
//    }
//    return dic;
//}

@end
