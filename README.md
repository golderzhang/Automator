# Automator

Automator是一款应用于iOS平台(ARC)的自动转换工具，可以轻松的实现Json、Dictionary与自定义Model之间的转换。

# 如何使用

- 下载工程Demo文件，拷贝Automator.h与Automator.m文件到需要的工程
- 创建自定义的Model，继承于Automator
- 在.h文件中创建需要的属性
- 如果属性类型是NSArray, 则只需要在.m文件中实现其class


.h
``` object-c
@interface Programmer: Automator
...
@property (nonatomic, strong) NSArray *skills;
@end
```
.m
``` object-c
#import "Skill.h"
@implementation
...
- (class)skills_class {
    return [Skill class];
}
@end
```

即可轻松使用！支持嵌套！


``` objective-c

NSDictionary *dic_pro = @{
    @"grade": @"2",
    @"name": @"golder",
    @"age": @26,
    @"workYears": @2.5,
    @"skills": @[@{@"des":@"OC", @"time":@3},@{@"des":@"PHP", @"time":@1}],
    @"company": @{@"name":@"Apple", @"address": @"美国"}
};

Programmer *programmer;
NSData *jsonData;
if ([NSJSONSerialization isValidJSONObject:dic_pro]) {
    jsonData = [NSJSONSerialization dataWithJSONObject:dic_pro options:NSJSONWritingPrettyPrinted error:NULL];
    programmer = [Programmer automatorWithJSONData:jsonData];
}

if (programmer) {
    NSData *data = [programmer autoJSONData];
}

```

# Sorry

- 目前不支持C指针类型，不过，Automator会自动忽略而不会引起Crash。
