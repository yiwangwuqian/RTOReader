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

- (NSArray<NSDictionary *> *_Nullable)attributesCheckRange:(NSRange)range haveSubRanges:(NSArray *_Nullable*_Nullable)subRanges
{
    if (self.rangeArray.count > 0 && self.attributesArray.count > 0 && subRanges != nil) {
        NSMutableArray *rangeArray = [[NSMutableArray alloc] init];
        NSMutableArray<NSDictionary *> *attributesArray = [[NSMutableArray alloc] init];
        
        for (NSInteger i=0; i<self.rangeArray.count; i++) {
            NSValue *oneRangeValue = self.rangeArray[i];
            NSRange oneRange = [oneRangeValue rangeValue];
            
            /**
             *第一个if和第一个else if，假设range被oneRange包含或者两者有部分区域是重合的
             *第二个else if，假设range可以包含oneRange
             */
            if (NSLocationInRange(range.location, oneRange)) {
                
                if (range.location + range.length < oneRange.location + oneRange.length) {
                    //被包含了
                    [rangeArray addObject:[NSValue valueWithRange:range]];
                    [attributesArray addObject:[self.attributesArray objectAtIndex:i]];
                } else {
                    //两者有重合区域
                    NSInteger length = oneRange.location + oneRange.length - range.location;
                    [rangeArray addObject:[NSValue valueWithRange:NSMakeRange(range.location, length)]];
                    [attributesArray addObject:[self.attributesArray objectAtIndex:i]];
                }
            } else if (NSLocationInRange(range.location+range.length, oneRange)) {
                //两者有重合区域
                NSInteger length = range.location+range.length - oneRange.location;
                [rangeArray addObject:[NSValue valueWithRange:NSMakeRange(oneRange.location, length)]];
                [attributesArray addObject:[self.attributesArray objectAtIndex:i]];
            } else if (NSLocationInRange(oneRange.location, range)) {
                [rangeArray addObject:[NSValue valueWithRange:NSMakeRange(oneRange.location, oneRange.length)]];
                [attributesArray addObject:[self.attributesArray objectAtIndex:i]];
            }
        }
        
        *subRanges = rangeArray;
        return attributesArray;
    }
    return nil;
}

@end
