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
 *第一次绘制完成
 */
- (void)firstPageEnd:(NSInteger)pageNum textId:(NSString *)textId isLast:(BOOL)isLast;
/**
 *具体某页绘制完成
 */
- (void)didDrawPageEnd:(NSInteger)pageNum textId:(NSString *)textId;
@end

/**
 *TXT相关功能的核心，便于iOS使用。
 */
@interface TLTXTCore : NSObject

@property(nonatomic,weak)id<TLTXTCoreDrawDelegate>  drawDelegate;

- (NSArray<NSValue *> *_Nullable)paragraphStartEnd:(NSInteger)page point:(CGPoint)point endIndex:(NSInteger *)endIndex textId:(NSString *)textId;

/**
 *某一页的所有段尾索引和rect
 */
- (NSDictionary<NSNumber *,NSValue *> *_Nullable)paragraphTailIndexAndRect:(NSInteger)page textId:(NSString *)textId;
/**
 *一次绘制多页(最大3页)，通常是第一次进入新打开的内容时缓存使用，也可用于改变了内容属性后刷新使用(即清空原有缓存)
 */
- (void)batchDraw:(NSInteger)pageNum textId:(nonnull NSString *)textId;

/**
 *根据页码来获取已缓存内容
 */
- (UIImage *_Nullable)onlyCachedImageWithPageNum:(NSInteger)pageNum textId:(NSString *)textId;

/**
 *根据将要使用内容的页码来决定是否缓存
 */
- (void)toCacheWhenMoveTo:(NSInteger)pageNum textId:(NSString *)textId whetherEnd:(BOOL*)whetherEnd;

/**
 *移除一段文字(内容)
 */
- (void)removeOnce:(NSString *)textId;

/**
 *获取属性字符串，修改属性使用
 */
- (TLAttributedString *)attributedStringWithTextId:(NSString *)textId;

/// 执行一次分页，返回结果为各页的游标，并返回最后一页的高度
/// - Parameters:
///   - textId: 文本id
///   - height: 最后一页的高度
- (NSArray<NSNumber *> *)oncePaging:(NSString *)textId endPageHeight:(CGFloat*)height;

+ (UIImage *)imageWith:(uint8_t *)bytes width:(CGFloat)bWidth height:(CGFloat)bHeight scale:(CGFloat)scale;
+ (UIImage *)imageWith:(uint8_t *)bytes width:(CGFloat)bWidth height:(CGFloat)bHeight scale:(CGFloat)scale nightMode:(BOOL)nightMode;
@end

@interface TLTXTCoreManager : NSObject

+ (instancetype)shared;

/// 获取一个TLTXTCore对象
/// - Parameter coreId: TLTXTCore对象的id
- (TLTXTCore *)coreWithId:(nonnull NSString *)coreId;

/// 为一段文字做准备，如果coreId对应的Core不存在则创建一个TLTXTCore对象保存起来
/// 如果存在则放入对应的Core
/// - Parameters:
///   - aString: 属性字符串
///   - size: 页面大小
///   - coreId: TLTXTCore对象的id，实际使用过程中对应一本书
- (void)prepareAttributedString:(TLAttributedString *)aString
                       pageSize:(CGSize)size
                         coreId:(NSString *)coreId;

/// 移除一个TLTXTCore对象
/// - Parameter coreId: TLTXTCore对象的id
- (void)removeOnce:(NSString *)coreId;


/// 移除一个所有对象
- (void)removeAllCore;

@end

NS_ASSUME_NONNULL_END
