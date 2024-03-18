//
//  TLTXTPageHelper.h
//  TextLayout
//
//  Created by guohy on 2022/10/28.
//  Copyright © 2022 ghy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "TLAttributedString.h"
#import "TLTXTAttributes.h"

@interface TLTXTPageHelper : NSObject

/// 检查属性字符串在某一范围内是否有属性
/// - Parameters:
///   - aString: 属性字符串
///   - range: 指定范围
///   - rArray: 范围数组
///   - aArray: 属性数组
+ (void)checkRangeAttributes:(TLAttributedString *)aString range:(TLRange)range rArray:(TLRangeArray *)rArray aArray:(TLTXTAttributesArray *)aArray;

/// 构造默认属性并返回
/// - Parameter aString: 属性字符串
+ (TLTXTAttributes)checkDefaultAttributes:(TLAttributedString *)aString;

@end
