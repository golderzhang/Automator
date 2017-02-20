//
//  Programmer.h
//  AutomatorDemo
//
//  Created by ZhangJinshi on 2017/2/20.
//  Copyright © 2017年 Golder. All rights reserved.
//

#import "Automator.h"
#import "Company.h"
#import "Skill.h"
@interface Programmer : Automator

@property (nonatomic) char *grade;  // 不支持C指针

@property (nonatomic, copy) NSString *name;
@property int age;
@property (nonatomic, strong) NSArray *skills;
@property (nonatomic, assign) double workYears;
@property (nonatomic, strong) Company *company;

@end
