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
- (void)firstPageEnd:(NSString *)textId;
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

/**
 *填入一段文本，指定页面大小，并使用已有的分页信息，指定开始绘制的页码
 *调用前需要检查pageNum小于cursorArray.count
 */
- (void)fillAttributedString:(TLAttributedString *)aString
                    pageSize:(CGSize)size
                 cursorArray:(NSArray<NSNumber *> *)cursorArray
                   startPage:(NSInteger)pageNum;

- (NSArray<NSValue *> *_Nullable)paragraphStartEnd:(NSInteger)page point:(CGPoint)point textId:(NSString *)textId;

- (void)firstTimeDraw:(BOOL)needsPaging startPage:(NSInteger)pageNum textId:(nonnull NSString *)textId;

/**
 *根据页码来获取已缓存内容
 */
- (UIImage *_Nullable)onlyCachedImageWithPageNum:(NSInteger)pageNum textId:(NSString *)textId;

/**
 *根据将要使用内容的页码来决定是否缓存
 */
- (void)toCacheWhenMoveTo:(NSInteger)pageNum textId:(NSString *)textId whetherEnd:(BOOL*)whetherEnd;

/// 执行一次分页，返回结果为各页的游标，并返回最后一页的高度
/// - Parameters:
///   - aString: 属性字符串
///   - pageSize: 页面大小
///   - height: 最后一页的高度
+ (NSArray<NSNumber *> *)oncePaging:(TLAttributedString *)aString pageSize:(CGSize)pageSize endPageHeight:(CGFloat*)height;
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
///   - cursorArray: 游标数组
///   - coreId: TLTXTCore对象的id，实际使用过程中对应一本书
- (void)prepareAttributedString:(TLAttributedString *)aString
                       pageSize:(CGSize)size
                    cursorArray:(NSArray<NSNumber *> *)cursorArray
                         coreId:(NSString *)coreId;

/// 移除一个TLTXTCore对象
/// - Parameter coreId: TLTXTCore对象的id
- (void)removeOnce:(NSString *)coreId;

@end

NS_ASSUME_NONNULL_END
