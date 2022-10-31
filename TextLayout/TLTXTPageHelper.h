//
//  TLTXTPageHelper.h
//  TextLayout
//
//  Created by guohy on 2022/10/28.
//  Copyright © 2022 ghy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TLAttributedString.h"
#import "TLTXTAttributes.h"

@interface TLTXTPageHelper : NSObject

/// 执行一次分页，返回结果为各页的游标，并返回最后一页的高度
/// - Parameters:
///   - aString: 属性字符串
///   - pageSize: 页面大小
///   - height: 最后一页的高度
+ (NSArray<NSNumber*> *)oncePaging:(TLAttributedString *)aString pageSize:(CGSize)pageSize endPageHeight:(CGFloat*)height;

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
