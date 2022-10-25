//
//  TLAttributedString.m
//  TextLayout
//
//  Created by guohy on 2022/10/25.
//  Copyright © 2022 ghy. All rights reserved.
//

#import "TLAttributedString.h"

@interface TLAttributedString()

/// 默认的属性
@property(nonatomic)NSDictionary                *defaultAttributes;

/// 需要被应用的属性的范围的数组，同一个索引值时和attributesArray中的元素是对应关系
@property(nonatomic)NSMutableArray<NSValue *>   *rangeArray;

/// 需要被应用的属性的数组，同一个索引值时和rangeArray中的元素是对应关系
@property(nonatomic)NSMutableArray              *attributesArray;

@property(nonatomic,copy)NSString               *string;

@end

@implementation TLAttributedString

- (instancetype)initWithString:(NSString *)str
                    attributes:(NSDictionary<NSNumber *, id> *)attrs
{
    self = [super init];
    if (self) {
        self.string = str;
        self.defaultAttributes = attrs;
        self.rangeArray = [[NSMutableArray alloc] init];
        self.attributesArray = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)addAttributes:(NSDictionary<NSNumber *,id> *)attrs range:(NSRange)range
{
    if (attrs != nil && range.length != 0) {
        [self.rangeArray addObject:[NSValue valueWithRange:range]];
        [self.attributesArray addObject:attrs];
    }
}

@end
