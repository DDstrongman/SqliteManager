# SqliteSpec


## Example

对于FMDB增删改查的所有方法的封装，同时支持单线程和多线程方法(queue后缀)，只需要传入**NSDictionary**或**Class**即可完成所有的增删改查工作。<br>
**不必再自己写SQL，详细使用方法请参考.h文件，好用请给star，不好用欢迎提建议～**<br>
栗子时间：<br>
```
/**
另起线程根据字典添加数据入库，重复情况delegate返回失败，delegate通知异步处理结果

@param tName 表名
@param dataClass 数据的模型类
*/
- (void)insertTableObjQueue:(NSString *)tName
                  DataModel:(Class)dataClass
```

## Installation

SqliteSpec is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "DDSqliteManager"
```

## Author

DDStrongman, lishengshu232@gmail.com

## License

SqliteSpec is available under the MIT license. See the LICENSE file for more info.
