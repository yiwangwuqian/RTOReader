//
//  TLAttributedString.h
//  TextLayout
//
//  Created by guohy on 2022/10/25.
//  Copyright © 2022 ghy. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TLAttributedString : NSObject

@property(nonatomic,readonly) NSString *string;
@property(nonatomic,readonly) NSString *textId;
@property(nonatomic,readonly)NSDictionary *defaultAttributes;

/// 创建对象
/// - Parameters:
///   - str: 内容
///   - attrs: 属性字典，NSNumber的key内部包含的是TLTXTAttributesNameType
- (instancetype)initWithString:(NSString *)str
                    attributes:(NSDictionary<NSNumber *, id> *)attrs;

/// 创建对象
/// - Parameters:
///   - str: 内容
///   - attrs: 属性字典，NSNumber的key内部包含的是TLTXTAttributesNameType
///   - textId: 文本Id用于各文本之间区分
- (instancetype)initWithString:(NSString *)str
                    attributes:(NSDictionary<NSNumber *, id> *)attrs
                        textId:(NSString *)textId;

/// 设置指定范围内的内容的属性，NSNumber的key内部包含的是TLTXTAttributesNameType
/// 该范围需要设置的所有属性应该一次性全出现在attrs里
/// 如果多次在某一range内用同一个TLTXTAttributesNameType设置属性，结果不可知
/// - Parameters:
///   - attrs: 属性字段
///   - range: 指定范围
- (void)addAttributes:(NSDictionary<NSNumber *, id> *)attrs
                range:(NSRange)range;

/// 对当前存在的所有属性进行检查，如果range内有属性，返回一组属性和对应的一组range
/// - Parameters:
///   - range: 待检查范围
///   - subRanges: 子返回数量与返回数组相等，元素与数组一一对应
- (NSArray<NSDictionary *> *_Nullable)attributesCheckRange:(NSRange)range haveSubRanges:(NSArray *_Nullable*_Nullable)subRanges;
@end

NS_ASSUME_NONNULL_END
