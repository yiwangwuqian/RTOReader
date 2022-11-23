//
//  TLTXTCore.m
//  TextLayout
//
//  Created by guohy on 2022/10/20.
//  Copyright © 2022 ghy. All rights reserved.
//

#define kTLTXTPerformanceLog 0

#define GetTimeDeltaValue(a) [[NSDate date] timeIntervalSince1970] - [(a) timeIntervalSince1970]

#import "TLTXTCore.h"
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

#import "TLTXTWorker.h"
#import "FileWrapper.h"

#import "TLGenericArray.h"
#import "TLTXTCachePage.h"
#import "TLTXTPageHelper.h"

dispatch_queue_t    pagingQueue;//分页专用
dispatch_queue_t    bitmapQueue;//bitmap绘制专用
dispatch_queue_t    imageQueue;//UIImage创建专用

/**
 *拆分业务逻辑，单个对象对应一段文本即单个txt文件
 *这样在TLTXTCore内聚合以后就支持处理多个txt文件
 */
@interface TLTXTCoreUnit : NSObject
@property(nonatomic)NSString            *unitBackupDirPath;
@property(nonatomic)NSString            *pageBackupDirPath;
@property(nonatomic,weak)id<TLTXTCoreDrawDelegate>  drawDelegate;
@property(nonatomic)TLAttributedString  *attributedString;
@property(nonatomic)NSString            *string;
@property(nonatomic)CGSize              pageSize;
@property(nonatomic)TLTXTWorker         worker;

@property(nonatomic)NSInteger           pageNum;//页码翻页时的判断使用 最后一次被请求的页码
@property(nonatomic)NSMutableArray      *cachedArray;//被缓存数组(每个元素包含有这些字段：页码、图片、图片中每个字位置信息)

/**
 *以下两个属性 内容的绘制和生成UIImage都是异步的，翻页时确保上一个操作完成了
 */
@property(nonatomic)dispatch_semaphore_t    nextPageSemaphore;
@property(nonatomic)dispatch_semaphore_t    previousPageSemaphore;
@property(nonatomic)BOOL                    needCleanCache;
@end

@implementation TLTXTCoreUnit

static void rangeAttributesFunc(TLTXTWorker worker,
                                TLRange range,
                                TLRangeArray *rArray,
                                TLTXTAttributesArray *aArray)
{
    TLTXTCoreUnit *txtCore = (__bridge TLTXTCoreUnit *)(txt_worker_get_context(worker));
    [TLTXTPageHelper checkRangeAttributes:txtCore.attributedString range:range rArray:rArray aArray:aArray];
}

static TLTXTAttributes defaultAttributesFunc(TLTXTWorker worker)
{
    TLTXTCoreUnit *txtCore = (__bridge TLTXTCoreUnit *)(txt_worker_get_context(worker));
    return [TLTXTPageHelper checkDefaultAttributes:txtCore.attributedString];
}

static bool isInAvoidLineStartFunc(TLTXTWorker worker,size_t char_index)
{
    NSString *charSetString = @"!%),.:;>?]}¢¨°·ˇˉ―‖’”…‰′″›℃∶、。〃〉》」』】〕〗〞︶︺︾﹀﹄﹚﹜﹞！＂％＇），．：；？］｀｜｝～￠";
    TLTXTCoreUnit *txtCore = (__bridge TLTXTCoreUnit *)(txt_worker_get_context(worker));
    if (txtCore.string.length > char_index) {
        NSString *onceString = [txtCore.string substringWithRange:NSMakeRange(char_index, 1)];
        return [charSetString containsString:onceString];
    }
    return false;
}

static bool isInAvoidLineEndFunc(TLTXTWorker worker,size_t char_index)
{
    NSString *charSetString = @"$([{￡￥·‘“〈《「『【〔〖〝﹙﹛﹝＄（．［｛￡￥";
    TLTXTCoreUnit *txtCore = (__bridge TLTXTCoreUnit *)(txt_worker_get_context(worker));
    NSString *onceString = [txtCore.string substringWithRange:NSMakeRange(char_index, 1)];
    if (txtCore.string.length > char_index) {
        NSString *onceString = [txtCore.string substringWithRange:NSMakeRange(char_index, 1)];
        return [charSetString containsString:onceString];
    }
    return false;
}

- (void)dealloc
{
#ifdef DEBUG
    NSLog(@"%@ dealloc", self);
#endif
    txt_worker_destroy(&_worker);
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _cachedArray = [NSMutableArray array];
        _pageNum = -1;
    }
    return self;
}


/// 设置属性字串准备绘制工作
///
/// 注意这个方法可以在同一段文字改变属性后再次调用，
/// 如果内容都变，那就是另外一段文字了需要销毁当前对象或新增方法。
/// - Parameters:
///   - aString: 属性字串
///   - size: 页面大小
///   - cursorArray: 游标数组，分页信息
- (void)resetAttributedString:(TLAttributedString *)aString
                     pageSize:(CGSize)size
{
    if (!aString) {
        return;
    } else if (CGSizeEqualToSize(size, CGSizeZero)) {
        return;
    }
    
    self.needCleanCache = _attributedString != nil;
    self.attributedString = aString;
    self.pageSize = size;
    self.string = [aString string];
    
    /**
     *对象创建也是需要消耗一些时间的，
     *内容不算长的情况下20毫秒，后续留意和验证一下需不需要这么做
     */
    /*
    if (!_worker) {
#ifdef kTLTXTPerformanceLog
        NSDate *createDate = [NSDate date];
#endif
        txt_worker_create(&_worker, [self.string UTF8String], size.width, size.height);
        txt_worker_set_context(_worker, (__bridge void *)(self));
        txt_worker_set_range_attributes_callback(_worker, rangeAttributesFunc);
        txt_worker_set_default_attributes_callback(_worker, defaultAttributesFunc);
#ifdef kTLTXTPerformanceLog
        NSLog(@"%s create _worker using time:%@", __func__, @(GetTimeDeltaValue(createDate) ));
#endif
    } else {
        txt_worker_page_cursor_array_destroy(_worker);
    }
     */
#if kTLTXTPerformanceLog
    NSDate *startDate = [NSDate date];
#endif
    txt_worker_create(&_worker, [[aString string] UTF8String], size.width, size.height);
    txt_worker_set_context(_worker, (__bridge void *)(self));
    txt_worker_set_range_attributes_callback(_worker, rangeAttributesFunc);
    txt_worker_set_default_attributes_callback(_worker, defaultAttributesFunc);
    txt_worker_set_avoid_line_start_callback(_worker, isInAvoidLineStartFunc);
    txt_worker_set_avoid_line_end_callback(_worker, isInAvoidLineEndFunc);
#if kTLTXTPerformanceLog
    NSLog(@"%s worker create using time:%@", __func__, @(GetTimeDeltaValue(startDate) ));
#endif
    
    self.pageNum = -1;
}

- (NSArray<NSNumber *> *)oncePaging:(CGFloat*)endPageHeight
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    dispatch_sync(pagingQueue, ^{
        if (!txt_worker_total_page(&self->_worker)) {
#if kTLTXTPerformanceLog
            NSDate *startDate = [NSDate date];
#endif
            *endPageHeight = txt_worker_data_paging(&self->_worker);
#if kTLTXTPerformanceLog
            NSLog(@"%s paging using time:%@", __func__, @(GetTimeDeltaValue(startDate) ));
#endif
        }
        
        size_t total_page = txt_worker_total_page(&self->_worker);
        if (total_page) {
            for (NSInteger i=0; i<total_page; i++) {
                size_t cursor = txt_worker_page_cursor_array_get(self->_worker, i);
                [result addObject:@(cursor)];
            }
        }
    });
    return result;
}

- (void)firstTimeDraw:(BOOL)needsPaging startPage:(NSInteger)pageNum
{
    dispatch_async(bitmapQueue, ^{
        /**
         *|A|-|B|-|C|
         *1.从第一页开始顺序翻页时，如果总页数大于3那么不管往左还是往右，
         *在进入B这一页时去缓存A或者C此时也应该调用本方法为上一或下一章节缓存
         *这个逻辑toCacheWhenMoveTo有判断
         *
         *2.如果顺序翻页停止后再退出，那么此时有可能停在某一章的第一页，
         *即在A的位置往左翻页此时外部也需要调用本方法
         *
         *所以这里加了if和return，外部如果有办法区分以上两种情况只调一次本方法时，
         *if和return才能去掉
         */
        if (!self.needCleanCache && self.cachedArray.count > 0) {
            return;
        }
        BOOL cleanCache = self.needCleanCache;
        self.needCleanCache = NO;
        if (needsPaging) {
#if kTLTXTPerformanceLog
            NSDate *pagingDate = [NSDate date];
#endif
            txt_worker_data_paging(&self->_worker);
#if kTLTXTPerformanceLog
            NSLog(@"%s paging using time:%@", __func__, @(GetTimeDeltaValue(pagingDate) ));
#endif
        }
        //调用三次对应绘制3页
        size_t total_page = txt_worker_total_page(&self->_worker);
        NSInteger loopCount = 3;
        NSInteger startPageNum = pageNum;
        if (total_page - startPageNum < loopCount) {
            //如果接近结尾
            
            if (total_page > loopCount) {
                //如果页数较多
                startPageNum = total_page - loopCount;
            } else {
                //如果页数较少 从头开始有多少页执行多少次
                startPageNum = 0;
                loopCount = total_page;
            }
        }
        for (NSInteger i=startPageNum; i<startPageNum+loopCount; i++) {
            TLTXTRowRectArray row_rect_array = NULL;
            TLGenericArray paragraph_tail_array = NULL;
            uint8_t *bitmap = txt_worker_bitmap_one_page(&self->_worker, i, &row_rect_array, &paragraph_tail_array);
            if (bitmap != NULL) {
                
                dispatch_async(imageQueue, ^{
                    NSNumber *nightMode = self.attributedString.defaultAttributes[@(TLTXTAttributesNameTypeColorMode)];
                    UIImage *image = [TLTXTCore imageWith:bitmap width:self.pageSize.width height:self.pageSize.height scale:1 nightMode:[nightMode integerValue]];
                    TLTXTCachePage *cachePage = [[TLTXTCachePage alloc] init];
                    cachePage.image = image;
                    cachePage.backupBytes = bitmap;
                    cachePage.pageNum = i;
                    cachePage.rowRectArray = row_rect_array;
                    cachePage.paragraphTailArray = paragraph_tail_array;
                    cachePage.cursor = txt_worker_page_cursor_array_get(self.worker, i);
                    cachePage.beforeCursor = i>0 ? txt_worker_page_cursor_array_get(self.worker, i-1) : -1;
                    //其它方法对cachedArray的赋值都在imageQueue，暂保持
                    if (cleanCache && i == startPageNum) {
                        self.cachedArray = [[NSMutableArray alloc] init];
                    }
                    [self.cachedArray addObject:cachePage];
                    NSInteger arrayCount = self.cachedArray.count;

                    if (self.drawDelegate) {
                        [self.drawDelegate firstPageEnd:i textId:self.attributedString.textId isLast:arrayCount == loopCount];
                    }
                    
                    if (arrayCount == loopCount) {
                        self.pageNum = 0;
                    }
                });
                
            }
        }
    });
}

- (NSArray<NSValue *> *_Nullable)paragraphStartEnd:(NSInteger)page point:(CGPoint)point endIndex:(NSInteger *)endIndex
{
    TLTXTCachePage *desPage;
    for (NSInteger i=0; i<self.cachedArray.count; i++) {
        TLTXTCachePage *oncePage = self.cachedArray[i];
        if (oncePage.pageNum == page) {
            desPage = oncePage;
            break;
        }
    }
    
    if (desPage){
        CGFloat scale = [UIScreen mainScreen].scale;
        point.x = scale * point.x;
        point.y = scale * point.y;

        NSInteger pStartIndex = -1;
        NSInteger pEndIndex = -1;
        NSInteger newLineIndex = -1;
        NSMutableArray *array = [[NSMutableArray alloc] init];
        
        NSInteger baseIndex = desPage.beforeCursor;
        if (baseIndex == -1) {
            baseIndex = 0;
        }
        
        /**
         *以下两个变量不会同时>=0
         */
        NSInteger rowIndex = -1;//被包含时的行索引
        NSInteger beforeRowIndex = -1;//所处位置的上一行的索引
        
        //先从y坐标判断属于第几行
        for (NSInteger i=0; i<desPage.rowRectArray->count; i++) {
            TLTXTRectArray data = desPage.rowRectArray->data[i];
            if (data->count > 0) {
                struct TLTXTRect_ firstRect = data->data[0];
                if (point.y >= firstRect.y && point.y <= firstRect.yy) {
                    rowIndex = i;
                    break;
                } else if (firstRect.y > point.y) {
                    if (i > 0) {
                        TLTXTRectArray beforeRowData = desPage.rowRectArray->data[i-1];
                        if (beforeRowData->count > 0) {
                            struct TLTXTRect_ beforeRowFirstRect = beforeRowData->data[0];
                            if (beforeRowFirstRect.yy < firstRect.y) {
                                beforeRowIndex = i-1;
                                break;
                            }
                        }
                    }
                }
            }
        }
        
        //既没有落在某一行文字之内也没有落在段内空白之内
        if (rowIndex == -1 && beforeRowIndex == -1) {
            return nil;
        }
        
        //排除在两段文字之间的情况
        if (beforeRowIndex >= 0) {
            TLTXTRectArray beforeRowData = desPage.rowRectArray->data[beforeRowIndex];
            if (beforeRowData->count > 0) {
                struct TLTXTRect_ lastRect = beforeRowData->data[beforeRowData->count-1];
                //beforeRowIndex不是最后一行 这里可以直接+1
                NSInteger lastRectNextIndex = lastRect.codepoint_index+1;
                NSString *oneString = [self.attributedString.string substringWithRange:NSMakeRange(lastRectNextIndex, 1)];
                if ([oneString isEqualToString: @"\n"]) {
                    //在某段最后一行之后的位置 没有哪段被选中
                    return nil;
                }
            }
        }
        
        for (NSInteger i=0; i<desPage.rowRectArray->count; i++) {
            TLTXTRectArray data = desPage.rowRectArray->data[i];
            if (data->count > 0) {
                struct TLTXTRect_ firstRect = data->data[0];
                struct TLTXTRect_ lastRect = data->data[data->count-1];
                if (pStartIndex == -1) {
                    if (firstRect.codepoint_index == 0 || i==0) {
                        //如果第一个字符是开头
                        newLineIndex = firstRect.codepoint_index;
                    } else if (firstRect.codepoint_index>0) {
                        NSInteger rectBeforeIndex = firstRect.codepoint_index - 1;
                        NSString *oneString = [self.attributedString.string substringWithRange:NSMakeRange(rectBeforeIndex, 1)];
                        if ([oneString isEqualToString: @"\n"]) {
                            //如果上一个字符是换行符
                            [array removeAllObjects];
                            newLineIndex = firstRect.codepoint_index;
                        }
                    }
                }
                
                if ((i == rowIndex || i == beforeRowIndex) && pStartIndex == -1) {
                    pStartIndex = newLineIndex;
                }
                
                if (pStartIndex >=0 && pEndIndex == -1) {
                    if (i == desPage.rowRectArray->count-1) {
                        //本页最后一行
                        pEndIndex = lastRect.codepoint_index;
                    } else {
                        NSInteger rectAfterIndex = lastRect.codepoint_index + 1;
                        NSString *oneString = [self.attributedString.string substringWithRange:NSMakeRange(rectAfterIndex, 1)];
                        if ([oneString isEqualToString: @"\n"]) {
                            //下一个字是换行
                            pEndIndex = lastRect.codepoint_index;
                        }
                    }
                }
                
                [array addObject:[NSValue valueWithCGRect:CGRectMake(firstRect.x, firstRect.y, firstRect.xx - firstRect.x, firstRect.yy - firstRect.y)]];
                
                if (data->count > 1) {
                    [array addObject:[NSValue valueWithCGRect:CGRectMake(lastRect.x, lastRect.y, lastRect.xx - lastRect.x, lastRect.yy - lastRect.y)]];
                }
                
                //pEndIndex被赋值此时结束
                if (pEndIndex >= 0) {
                    break;
                }
            }
            
            if (pStartIndex >=0 && pEndIndex >=0) {
                break;
            }
        }
        
        
        if (pStartIndex >=0 && pEndIndex >=0) {
            //找了具体某一段
        } else if (pStartIndex >=0) {
            //只有开始没有结束
        } else if (pEndIndex >=0) {
            //只有结束没有开始
        } else {
            //一整屏的文字没有换行
        }
        
        NSArray *tempArray = [NSArray arrayWithArray:array];
        [array removeAllObjects];
        for (NSValue *rectValue in tempArray) {
            CGRect onceRect = [rectValue CGRectValue];
            onceRect.origin.x = onceRect.origin.x/scale;
            onceRect.origin.y = onceRect.origin.y/scale;
            onceRect.size.width = onceRect.size.width/scale;
            onceRect.size.height = onceRect.size.height/scale;
            [array addObject:[NSValue valueWithCGRect:onceRect]];
        }
        
        if (pEndIndex >= 0 && *endIndex) {
            *endIndex = pEndIndex;
        }
        if (pStartIndex >=0) {
            NSMutableArray *result = [[NSMutableArray alloc] init];
            
            CGFloat lastOriginY = [array.firstObject CGRectValue].origin.y;
            CGFloat lastOriginX = [array.firstObject CGRectValue].origin.x;
            for (NSInteger i = 0; i<array.count; i++) {
                CGRect onceRect = [array[i] CGRectValue];
                if (onceRect.origin.y > lastOriginY) {
                    CGRect beforeRect = [array[i-1] CGRectValue];
                    [result addObject:[NSValue valueWithCGRect:CGRectMake(lastOriginX, lastOriginY, CGRectGetMaxX(beforeRect)-lastOriginX, CGRectGetMaxY(beforeRect) - lastOriginY)]];
                    
                    lastOriginY = onceRect.origin.y;
                    lastOriginX = onceRect.origin.x;
                }
                if (i == array.count - 1) {
                    [result addObject:[NSValue valueWithCGRect:CGRectMake(lastOriginX, lastOriginY, CGRectGetMaxX(onceRect)-lastOriginX, CGRectGetMaxY(onceRect) - lastOriginY)]];
                }
            }
            //return array
            /**
             *之前是返回array，但是现在可能选中的段落中某些行有字间距(kern)
             *上面的for循环里把每一行转用一个CGRect来表示了
             */
            return result;
        }
    }
    return nil;
}

- (NSDictionary<NSNumber *,NSValue *> *_Nullable)paragraphTailIndexAndRect:(NSInteger)page
{
    TLTXTCachePage *desPage;
    for (NSInteger i=0; i<self.cachedArray.count; i++) {
        TLTXTCachePage *oncePage = self.cachedArray[i];
        if (oncePage.pageNum == page) {
            desPage = oncePage;
            break;
        }
    }
    
    if (desPage && desPage.paragraphTailArray) {
        CGFloat scale = [UIScreen mainScreen].scale;
        NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
        
        NSInteger tailCount = tl_generic_array_get_count(desPage.paragraphTailArray);
        NSInteger tailIndex = 0;
        for (NSInteger i=0; i<desPage.rowRectArray->count; i++) {
            TLTXTRectArray data = desPage.rowRectArray->data[i];
            NSInteger oneRowCount = txt_worker_rect_array_get_count(&data);
            TLTXTRect one_row_last_rect = txt_worker_rect_array_object_at(&data, (int)oneRowCount-1 );
            if (tailIndex < tailCount) {
                NSInteger onceTailIndex = tl_generic_array_object_at(desPage.paragraphTailArray, (int)tailIndex);
                if (one_row_last_rect->codepoint_index == onceTailIndex) {
                    CGRect onceRect;
                    onceRect.origin.x = one_row_last_rect->x/scale;
                    onceRect.origin.y = one_row_last_rect->y/scale;
                    onceRect.size.width = (one_row_last_rect->xx - one_row_last_rect->x)/scale;
                    onceRect.size.height = (one_row_last_rect->yy - one_row_last_rect->y)/scale;
                    [result setObject:@(onceRect) forKey:@(onceTailIndex)];
                    tailIndex++;
                }
            }
        }
        return result;
    }
    return nil;
}

- (UIImage *_Nullable)onlyCachedImageWithPageNum:(NSInteger)pageNum
{
    if (pageNum >=0 && pageNum < [self totalPage] && self.cachedArray.count) {
        TLTXTCachePage *cachePage = nil;
        for (NSInteger i=0; i<self.cachedArray.count; i++) {
            TLTXTCachePage *oncePage = self.cachedArray[i];
            if (oncePage.pageNum == pageNum) {
                cachePage = oncePage;
            }
        }
#ifdef DEBUG
        if (!cachePage.image) {
            NSLog(@"%s %@ pageNum %@ self.cachedArray %@", __FUNCTION__, self, @(pageNum), self.cachedArray);
        }
#endif
        return cachePage.image;
    }
#ifdef DEBUG
    NSLog(@"%s %@ pageNum %@ self.cachedArray %@", __FUNCTION__, self, @(pageNum), self.cachedArray);
#endif
    return nil;
}

///  从传入的页码判断该缓存哪一页内容
/// - Parameters:
///   - pageNum: 页码
///   - whetherEnd: 在当前方向是否到了结束的位置
- (void)toCacheWhenMoveTo:(NSInteger)pageNum whetherEnd:(BOOL *)whetherEnd
{
//#ifdef DEBUG
//    NSLog(@"%s ⚠️pageNum %@ textId:%@", __FUNCTION__, @(pageNum), self.attributedString.textId);
//#endif
    //self.pageNum初始化为-1所以>=0表示可以去缓存了
    if (self.pageNum >=0 && pageNum >=0 && pageNum < [self totalPage] && self.cachedArray.count) {
        NSInteger index = -1;
        for (NSInteger i=0; i<self.cachedArray.count; i++) {
            TLTXTCachePage *oncePage = self.cachedArray[i];
            if (oncePage.pageNum == pageNum) {
                index = i;
            }
        }
        bool pageNumIsEqual = true;
        if (self.pageNum != pageNum){
            self.pageNum = pageNum;
            pageNumIsEqual = false;
        }
        if (index == 0) {
            if (pageNum == 0) {
                if (whetherEnd) {
                    *whetherEnd = YES;
                }
            } else {
                if (!pageNumIsEqual){
                    [self toPreviousPage];
                    //大于两页的情况下 上一句是去缓存第一页内容
                    if (whetherEnd && [self totalPage] > 2 && pageNum == 1) {
                        *whetherEnd = YES;
                    }
                }
            }
        } else if (index == self.cachedArray.count -1) {
            if (pageNum == [self totalPage]-1) {
                if (whetherEnd) {
                    *whetherEnd = YES;
                }
            } else {
                if (!pageNumIsEqual){
                    [self toNextPage];
                    //大于两页的情况下 上一句是去缓存最后一页内容
                    if (whetherEnd && [self totalPage] > 2 && pageNum == [self totalPage] - 2) {
                        *whetherEnd = YES;
                    }
                }
            }
        }
#ifdef DEBUG
        if (index == -1) {
            NSMutableArray *numberArray = [[NSMutableArray alloc] init];
            for (NSInteger i=0; i<self.cachedArray.count; i++) {
                TLTXTCachePage *oncePage = self.cachedArray[i];
                [numberArray addObject:@(oncePage.pageNum)];
            }
            NSLog(@"⚠️pageNum %@ not in %@ things wrong!!!", @(pageNum), [numberArray componentsJoinedByString:@","]);
        }
#endif
    }
}

- (NSInteger)totalPage
{
    return txt_worker_total_page(&_worker);
}

#pragma mark- Private methods

- (void)toNextPage
{
    //信号量的赋值视为在主线程
    if (self.nextPageSemaphore) {
        dispatch_semaphore_wait(self.nextPageSemaphore, DISPATCH_TIME_FOREVER);
    }
    if (!(self.pageNum + 1 < [self totalPage])) {
        return;
    }
    NSInteger afterPageNum = self.pageNum+1;
    self.nextPageSemaphore = dispatch_semaphore_create(0);
    
    dispatch_async(bitmapQueue, ^{
#ifdef DEBUG
        NSLog(@"⚠️begin draw %@ %s textId:%@", @(afterPageNum), __FUNCTION__, self.attributedString.textId);
#endif
    
#if kTLTXTPerformanceLog
    NSDate *date = [NSDate date];
#endif

#if kTLTXTPerformanceLog
    NSDate *bitmapStartDate = [NSDate date];
#endif
    TLTXTRowRectArray row_rect_array = NULL;
    TLGenericArray paragraph_tail_array = NULL;
    uint8_t *bitmap = txt_worker_bitmap_one_page(&self->_worker,afterPageNum, &row_rect_array, &paragraph_tail_array);
#if kTLTXTPerformanceLog
    NSLog(@"%s bitmap using time:%@", __func__, @(GetTimeDeltaValue(bitmapStartDate) ));
#endif
    if (bitmap != NULL) {
        
        dispatch_async(imageQueue, ^{
#if kTLTXTPerformanceLog
            NSDate *imageStartDate = [NSDate date];
#endif
            NSNumber *nightMode = self.attributedString.defaultAttributes[@(TLTXTAttributesNameTypeColorMode)];
            UIImage *image = [TLTXTCore imageWith:bitmap width:self.pageSize.width height:self.pageSize.height scale:1 nightMode:[nightMode integerValue]];
            TLTXTCachePage *cachePage = [[TLTXTCachePage alloc] init];
            cachePage.pageNum = afterPageNum;
            cachePage.image = image;
            cachePage.backupPath = self.pageBackupDirPath;
            cachePage.backupBytes = bitmap;
            cachePage.rowRectArray = row_rect_array;
            cachePage.paragraphTailArray = paragraph_tail_array;
            cachePage.cursor = txt_worker_page_cursor_array_get(self.worker, afterPageNum);
            cachePage.beforeCursor = afterPageNum>0 ? txt_worker_page_cursor_array_get(self.worker, afterPageNum-1) : -1;
            NSMutableArray *array = [NSMutableArray arrayWithArray:self.cachedArray];
            [array removeObjectAtIndex:0];
            [array addObject:cachePage];
            
            self.cachedArray = array;
            
#ifdef DEBUG
            NSMutableArray *numberArray = [[NSMutableArray alloc] init];
            for (NSInteger i=0; i<self.cachedArray.count; i++) {
                TLTXTCachePage *oncePage = self.cachedArray[i];
                [numberArray addObject:@(oncePage.pageNum)];
            }
            NSLog(@"⚠️end draw %@ %s %@ textId:%@", @(afterPageNum), __FUNCTION__, [numberArray componentsJoinedByString:@","], self.attributedString.textId);
#endif
            
#if kTLTXTPerformanceLog
            NSLog(@"%s image create using time:%@", __func__, @(GetTimeDeltaValue(imageStartDate) ));
#endif
            
#if kTLTXTPerformanceLog
    NSLog(@"%s using time:%@", __func__, @(GetTimeDeltaValue(date) ));
#endif
            dispatch_semaphore_signal(self.nextPageSemaphore);
            if (self.drawDelegate) {
                [self.drawDelegate didDrawPageEnd:afterPageNum textId:self.attributedString.textId];
            }
        });
            
    } else {
        dispatch_semaphore_signal(self.nextPageSemaphore);
    }
    });
}

- (void)toPreviousPage
{
    //信号量的赋值视为在主线程
    if (self.previousPageSemaphore) {
        dispatch_semaphore_wait(self.previousPageSemaphore, DISPATCH_TIME_FOREVER);
    }
    if (!(self.pageNum > 0)) {
        return;
    }
    NSInteger afterPageNum = self.pageNum-1;
    self.previousPageSemaphore = dispatch_semaphore_create(0);
    dispatch_async(bitmapQueue, ^{
#ifdef DEBUG
        NSLog(@"⚠️begin draw %@ %s textId:%@", @(afterPageNum), __FUNCTION__, self.attributedString.textId);
#endif
    
#if kTLTXTPerformanceLog
    NSDate *date = [NSDate date];
#endif

#if kTLTXTPerformanceLog
    NSDate *bitmapStartDate = [NSDate date];
#endif
    TLTXTRowRectArray row_rect_array = NULL;
    TLGenericArray paragraph_tail_array = NULL;
    uint8_t *bitmap = txt_worker_bitmap_one_page(&self->_worker,afterPageNum, &row_rect_array, &paragraph_tail_array);
#if kTLTXTPerformanceLog
    NSLog(@"%s bitmap using time:%@", __func__, @(GetTimeDeltaValue(bitmapStartDate) ));
#endif
    if (bitmap != NULL) {
        
        dispatch_async(imageQueue, ^{
#if kTLTXTPerformanceLog
            NSDate *imageStartDate = [NSDate date];
#endif
            NSNumber *nightMode = self.attributedString.defaultAttributes[@(TLTXTAttributesNameTypeColorMode)];
            UIImage *image = [TLTXTCore imageWith:bitmap width:self.pageSize.width height:self.pageSize.height scale:1 nightMode:[nightMode integerValue]];
            TLTXTCachePage *cachePage = [[TLTXTCachePage alloc] init];
            cachePage.pageNum = afterPageNum;
            cachePage.image = image;
            cachePage.backupPath = self.pageBackupDirPath;
            cachePage.backupBytes = bitmap;
            cachePage.rowRectArray = row_rect_array;
            cachePage.paragraphTailArray = paragraph_tail_array;
            cachePage.cursor = txt_worker_page_cursor_array_get(self.worker, afterPageNum);
            cachePage.beforeCursor = afterPageNum>0 ? txt_worker_page_cursor_array_get(self.worker, afterPageNum-1) : -1;
            NSMutableArray *array = [NSMutableArray arrayWithArray:self.cachedArray];
            [array removeObjectAtIndex:2];
            [array insertObject:cachePage atIndex:0];
            self.cachedArray = array;
#ifdef DEBUG
            NSMutableArray *numberArray = [[NSMutableArray alloc] init];
            for (NSInteger i=0; i<self.cachedArray.count; i++) {
                TLTXTCachePage *oncePage = self.cachedArray[i];
                [numberArray addObject:@(oncePage.pageNum)];
            }
            NSLog(@"⚠️end draw %@ %s %@ textId:%@", @(afterPageNum), __FUNCTION__, [numberArray componentsJoinedByString:@","], self.attributedString.textId);
#endif
            
#if kTLTXTPerformanceLog
            NSLog(@"%s image create using time:%@", __func__, @(GetTimeDeltaValue(imageStartDate) ));
#endif
            
#if kTLTXTPerformanceLog
    NSLog(@"%s using time:%@", __func__, @(GetTimeDeltaValue(date) ));
#endif
            dispatch_semaphore_signal(self.previousPageSemaphore);
            if (self.drawDelegate) {
                [self.drawDelegate didDrawPageEnd:afterPageNum textId:self.attributedString.textId];
            }
        });
            
    } else {
        dispatch_semaphore_signal(self.previousPageSemaphore);
    }
    });
}

- (NSString *)pageBackupDirPath
{
    if (!_pageBackupDirPath) {
        _pageBackupDirPath = [self.unitBackupDirPath stringByAppendingPathComponent:self.attributedString.textId];
    }
    return _pageBackupDirPath;
}

- (void)checkCachedImageBackup
{
    NSArray *cachedArray = self.cachedArray;
    for (TLTXTCachePage *onePage in cachedArray) {
        [onePage saveBackup];
    }
}

- (void)checkCachedImageRestore
{
    NSArray *cachedArray = self.cachedArray;
    for (TLTXTCachePage *onePage in cachedArray) {
        [onePage restoreBackup];
    }
}

@end

@interface TLTXTCore()

@property(nonatomic)NSString        *backupDirPath;
@property(nonatomic)NSString        *coreId;
@property(nonatomic)NSMutableArray  *unitArray;

@end

@implementation TLTXTCore

- (void)dealloc
{
#ifdef DEBUG
    NSLog(@"%@ dealloc", self);
#endif
}

+(void)load
{
    if (pagingQueue == NULL) {
        pagingQueue = dispatch_queue_create("TextLayout.paging", DISPATCH_QUEUE_SERIAL);
    }
    if (bitmapQueue == NULL) {
        bitmapQueue = dispatch_queue_create("TextLayout.bitmap", DISPATCH_QUEUE_SERIAL);
    }
    if (imageQueue == NULL) {
        imageQueue = dispatch_queue_create("TextLayout.image", DISPATCH_QUEUE_SERIAL);
    }
}

- (void)setDrawDelegate:(id<TLTXTCoreDrawDelegate>)drawDelegate
{
    _drawDelegate = drawDelegate;
    @synchronized (self.unitArray) {
        NSArray *unitArray = self.unitArray;
        for (TLTXTCoreUnit *oneUnit in unitArray) {
            oneUnit.drawDelegate = drawDelegate;
        }
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _unitArray = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)fillAttributedString:(TLAttributedString *)aString
                    pageSize:(CGSize)size
{
    TLTXTCoreUnit *unit = [self unitWithTextId:aString.textId];
    if (!unit) {
        unit = [[TLTXTCoreUnit alloc] init];
        unit.unitBackupDirPath = self.backupDirPath;
        @synchronized (self.unitArray) {
            [self.unitArray addObject:unit];
        }
    }
    unit.drawDelegate = self.drawDelegate;
    [unit resetAttributedString:aString pageSize:size];
}

- (NSArray<NSValue *> *_Nullable)paragraphStartEnd:(NSInteger)page point:(CGPoint)point endIndex:(NSInteger *)endIndex textId:(NSString *)textId
{
    TLTXTCoreUnit *unit = [self unitWithTextId:textId];
    return [unit paragraphStartEnd:page point:point endIndex:endIndex];
}

- (NSDictionary<NSNumber *,NSValue *> *_Nullable)paragraphTailIndexAndRect:(NSInteger)page textId:(NSString *)textId
{
    TLTXTCoreUnit *unit = [self unitWithTextId:textId];
    return [unit paragraphTailIndexAndRect:page];
}

- (UIImage *_Nullable)onlyCachedImageWithPageNum:(NSInteger)pageNum textId:(nonnull NSString *)textId
{
    TLTXTCoreUnit *unit = [self unitWithTextId:textId];
    return [unit onlyCachedImageWithPageNum:pageNum];
}

- (void)batchDraw:(NSInteger)pageNum textId:(NSString *)textId
{
    TLTXTCoreUnit *unit = [self unitWithTextId:textId];
    [unit firstTimeDraw:NO startPage:pageNum];
}

- (void)toCacheWhenMoveTo:(NSInteger)pageNum textId:(NSString *)textId whetherEnd:(BOOL*)whetherEnd
{
    TLTXTCoreUnit *unit = [self unitWithTextId:textId];
    [unit toCacheWhenMoveTo:pageNum whetherEnd:whetherEnd];
}

- (void)removeOnce:(NSString *)textId
{
    TLTXTCoreUnit *unit = [self unitWithTextId:textId];
    if (unit) {
        @synchronized (self.unitArray) {
            [self.unitArray removeObject:unit];
        }
    }
}

- (TLAttributedString *)attributedStringWithTextId:(NSString *)textId
{
    TLTXTCoreUnit *unit = [self unitWithTextId:textId];
    return unit.attributedString;
}

- (NSArray<NSNumber *> *)oncePaging:(NSString *)textId endPageHeight:(CGFloat*)height
{
    TLTXTCoreUnit *unit = [self unitWithTextId:textId];
    return [unit oncePaging:height];
}

+ (UIImage *)imageWith:(uint8_t *)bytes width:(CGFloat)bWidth height:(CGFloat)bHeight scale:(CGFloat)scale
{
    NSInteger componentsCount = 4;
    CGFloat width = bWidth;
    CGFloat height = bHeight;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef contextRef = CGBitmapContextCreate(bytes,                 // Pointer to backing data
                                                    width,                       // Width of bitmap
                                                    height,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    width*componentsCount,              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big); // Bitmap info flags
    CGImageRef mainViewContentBitmapContext = CGBitmapContextCreateImage(contextRef);
    CGContextRelease(contextRef);
    UIImage *result = [UIImage imageWithCGImage:mainViewContentBitmapContext scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(mainViewContentBitmapContext);
    return result;
}

+ (UIImage *)imageWith:(uint8_t *)bytes width:(CGFloat)bWidth height:(CGFloat)bHeight scale:(CGFloat)scale nightMode:(BOOL)nightMode
{
    /**
     *为什么要再次封装：实际上下面这一句内部bitmap转UIImage就有alpha的操作，最终图片也体现了透明度。
     *
     *但是很奇怪在纯黑的背景色时，那些锯齿上的alpha值没有效果，也许是苹果的bug，暂如以下代码处理。
     *实际上在Xcode的debug工具预览下是能看到效果的，只是app看不到。
     */
    UIImage *result = [self imageWith:bytes width:bWidth height:bHeight scale:scale];
    if (nightMode) {
#if kTLTXTPerformanceLog
        NSDate *pngStartDate = [NSDate date];
#endif
        NSData *data = UIImagePNGRepresentation(result);
        result = [[UIImage alloc] initWithData:data];
#if kTLTXTPerformanceLog
        NSLog(@"%s to png using time:%@", __func__, @(GetTimeDeltaValue(pngStartDate) ));
#endif
        return result;
    }
    return result;
}

#pragma mark- Private methods

- (TLTXTCoreUnit *)unitWithTextId:(nonnull NSString *)textId
{
    @synchronized (self.unitArray) {
        TLTXTCoreUnit *unit = nil;
        NSArray *unitArray = self.unitArray;
        for (TLTXTCoreUnit *oneUnit in unitArray) {
            if ([oneUnit.attributedString.textId isEqualToString:textId]) {
                unit = oneUnit;
                break;
            }
        }
        return unit;
    }
}

- (NSString *)backupDirPath
{
    if (!_backupDirPath) {
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        _backupDirPath = [documentsPath stringByAppendingPathComponent:[NSString stringWithFormat:@".TextLayoutCache/%@", self.coreId]];
    }
    return _backupDirPath;
}

@end

@interface TLTXTCoreManager()

@property(nonatomic)NSMutableArray *coreArray;

@end

@implementation TLTXTCoreManager

static TLTXTCoreManager *manager = nil;

+ (instancetype)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _coreArray = [[NSMutableArray alloc] init];
    }
    return self;
}

- (TLTXTCore *)coreWithId:(nonnull NSString *)coreId
{
    TLTXTCore *core = nil;
    NSArray *coreArray = self.coreArray;
    for (TLTXTCore *oneCore in coreArray) {
        if ([oneCore.coreId isEqualToString:coreId]) {
            core = oneCore;
            break;
        }
    }
    return core;
}

- (void)prepareAttributedString:(TLAttributedString *)aString
                       pageSize:(CGSize)size
                         coreId:(NSString *)coreId
{
    TLTXTCore *core = [self coreWithId:coreId];
    if (!core) {
        core = [[TLTXTCore alloc] init];
        core.coreId = coreId;
        [self.coreArray addObject:core];
    }
    [core fillAttributedString:aString pageSize:size];
}

- (void)removeOnce:(NSString *)coreId
{
    NSArray *coreArray = self.coreArray;
    for (TLTXTCore *oneCore in coreArray) {
        if ([oneCore.coreId isEqualToString:coreId]) {
            [self.coreArray removeObject:oneCore];
            break;
        }
    }
}

- (void)removeAllCore
{
    [self.coreArray removeAllObjects];
}

@end
