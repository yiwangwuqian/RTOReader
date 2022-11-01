//
//  TLTXTCore.h
//  TextLayout
//
//  Created by guohy on 2022/10/20.
//  Copyright © 2022 ghy. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "TLTXTTypes.h"
#import "TLAttributedString.h"


NS_ASSUME_NONNULL_BEGIN

@protocol TLTXTCoreDrawDelegate <NSObject>

/**
 *第一页绘制完成
 */
- (void)firstPageEnd;

@end

/**
 *TXT相关功能的核心，便于iOS使用。
 */
@interface TLTXTCore : NSObject

@property(nonatomic,weak)id<TLTXTCoreDrawDelegate>  drawDelegate;

/**
 *重置内容和页面大小
 */
- (void)resetAttributedString:(TLAttributedString *)aString pageSize:(CGSize)size;

/**
 *重置内容和页面大小，并使用已有的分页信息
 */
- (void)resetAttributedString:(TLAttributedString *)aString
                     pageSize:(CGSize)size
                  cursorArray:(NSArray<NSNumber *> *)cursorArray;

/**
 *获取上一页的内容，并继续向上一页进一步
 */
- (UIImage *)toPreviousPageOnce;

/**
 *获取下一页的内容，并继续向下一页进一步
 */
- (UIImage *)toNextPageOnce;

/// 获取段落的开始和结束位置坐标，返回CGPoint
/// - Parameters:
///   - page: 页码
///   - point: 点坐标，用户手势的位置
- (NSArray<NSValue *> *_Nullable)paragraphStartEnd:(NSInteger)page point:(CGPoint)point;
/**
 *根据页码来决定是否使用已有内容
 */
- (UIImage *)imageWithPageNum:(NSInteger)pageNum;

- (NSInteger)totalPage;

/// 执行一次分页，返回结果为各页的游标，并返回最后一页的高度
/// - Parameters:
///   - aString: 属性字符串
///   - pageSize: 页面大小
///   - height: 最后一页的高度
+ (NSArray<NSNumber *> *)oncePaging:(TLAttributedString *)aString pageSize:(CGSize)pageSize endPageHeight:(CGFloat*)height;
@end

NS_ASSUME_NONNULL_END
