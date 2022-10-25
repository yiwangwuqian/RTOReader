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

@property(readonly) NSString *string;

/// 创建对象
/// - Parameters:
///   - str: 内容
///   - attrs: 属性字典，NSNumber的key内部包含的是TLTXTAttributesNameType
- (instancetype)initWithString:(NSString *)str
                    attributes:(NSDictionary<NSNumber *, id> *)attrs;

/// 设置指定范围内的内容的属性，NSNumber的key内部包含的是TLTXTAttributesNameType
/// - Parameters:
///   - attrs: 属性字段
///   - range: 指定范围
- (void)addAttributes:(NSDictionary<NSNumber *, id> *)attrs
                range:(NSRange)range;

@end

NS_ASSUME_NONNULL_END
