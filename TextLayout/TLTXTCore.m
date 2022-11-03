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

#import "TLTXTCachePage.h"
#import "TLTXTPageHelper.h"

dispatch_queue_t    bitmapQueue;//bitmap绘制专用
dispatch_queue_t    imageQueue;//UIImage创建专用

/**
 *拆分业务逻辑，单个对象对应一段文本即单个txt文件
 *这样在TLTXTCore内聚合以后就支持处理多个txt文件
 */
@interface TLTXTCoreUnit : NSObject
@property(nonatomic,weak)id<TLTXTCoreDrawDelegate>  drawDelegate;
@property(nonatomic)TLAttributedString  *attributedString;
@property(nonatomic)CGSize              pageSize;
@property(nonatomic)TLTXTWorker         worker;

@property(nonatomic)NSInteger           pageNum;//页码翻页时的判断使用 最后一次被请求的页码
@property(nonatomic)NSMutableArray      *cachedArray;//被缓存数组(每个元素包含有这些字段：页码、图片、图片中每个字位置信息)

/**
 *以下两个属性 内容的绘制和生成UIImage都是异步的，翻页时确保上一个操作完成了
 */
@property(nonatomic)dispatch_semaphore_t    nextPageSemaphore;
@property(nonatomic)dispatch_semaphore_t    previousPageSemaphore;
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

- (void)resetAttributedString:(TLAttributedString *)aString
                     pageSize:(CGSize)size
                  cursorArray:(NSArray<NSNumber *> *)cursorArray
                    startPage:(NSInteger)pageNum
{
    if (!aString) {
        return;
    } else if (CGSizeEqualToSize(size, CGSizeZero)) {
        return;
    }
    
    self.attributedString = aString;
    self.pageSize = size;
    
    if (_worker) {
        txt_worker_destroy(&_worker);
        _worker = NULL;
    }
    
    txt_worker_create(&_worker, [[aString string] UTF8String], size.width, size.height);
    txt_worker_set_context(_worker, (__bridge void *)(self));
    txt_worker_set_range_attributes_callback(_worker, rangeAttributesFunc);
    txt_worker_set_default_attributes_callback(_worker, defaultAttributesFunc);
    if (cursorArray.count) {
        for (NSNumber *number in cursorArray) {
            txt_worker_page_cursor_array_prefill(_worker, [number integerValue]);
        }
        txt_worker_total_page_prefill(_worker, cursorArray.count);
    }
    
    self.pageNum = -1;
    [self firstTimeDraw:NO startPage:pageNum];
}

- (void)resetAttributedString:(TLAttributedString *)aString
                     pageSize:(CGSize)size
                  cursorArray:(NSArray<NSNumber *> *)cursorArray
{
    if (!aString) {
        return;
    } else if (CGSizeEqualToSize(size, CGSizeZero)) {
        return;
    }
    
    self.attributedString = aString;
    self.pageSize = size;
    
    if (_worker) {
        txt_worker_destroy(&_worker);
        _worker = NULL;
    }
    
    txt_worker_create(&_worker, [[aString string] UTF8String], size.width, size.height);
    txt_worker_set_context(_worker, (__bridge void *)(self));
    txt_worker_set_range_attributes_callback(_worker, rangeAttributesFunc);
    txt_worker_set_default_attributes_callback(_worker, defaultAttributesFunc);
    if (cursorArray.count) {
        for (NSNumber *number in cursorArray) {
            txt_worker_page_cursor_array_prefill(_worker, [number integerValue]);
        }
        txt_worker_total_page_prefill(_worker, cursorArray.count);
    }
    
    self.pageNum = -1;
}

- (void)firstTimeDraw:(BOOL)needsPaging startPage:(NSInteger)pageNum
{
    dispatch_async(bitmapQueue, ^{
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
            uint8_t *bitmap = txt_worker_bitmap_one_page(&self->_worker, i, &row_rect_array);
            if (bitmap != NULL) {
                
                dispatch_async(imageQueue, ^{
                    UIImage *image = [[self class] imageWith:bitmap width:self.pageSize.width height:self.pageSize.height scale:1];
                    TLTXTCachePage *cachePage = [[TLTXTCachePage alloc] init];
                    cachePage.image = image;
                    cachePage.pageNum = i;
                    cachePage.rowRectArray = row_rect_array;
                    cachePage.cursor = txt_worker_page_cursor_array_get(self.worker, i);
                    cachePage.beforeCursor = i>0 ? txt_worker_page_cursor_array_get(self.worker, i-1) : -1;
                    [self.cachedArray addObject:cachePage];
                    NSInteger arrayCount = self.cachedArray.count;
                    
                    if (arrayCount == loopCount && self.drawDelegate) {
                        self.pageNum = 0;
                        [self.drawDelegate firstPageEnd:self.attributedString.textId];
                    }
                });
                
            }
        }
    });
}

- (NSArray<NSValue *> *_Nullable)paragraphStartEnd:(NSInteger)page point:(CGPoint)point
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
        
        for (NSInteger i=0; i<desPage.rowRectArray->count; i++) {
            TLTXTRectArray data = desPage.rowRectArray->data[i];
            if (data->count > 0) {
                for (NSInteger j=0; j<data->count; j++) {
                    struct TLTXTRect_ rect = data->data[j];
                    
                    if (pStartIndex == -1) {
                        if (rect.codepoint_index == 0 || (i==0 && j==0)) {
                            //如果第一个字符是开头
                            [array removeAllObjects];
                            newLineIndex = rect.codepoint_index;
                        } else if (rect.codepoint_index>0) {
                            NSInteger rectBeforeIndex = rect.codepoint_index - 1;
                            NSString *oneString = [self.attributedString.string substringWithRange:NSMakeRange(rectBeforeIndex, 1)];
                            if ([oneString isEqualToString: @"\n"]) {
                                //如果上一个字符是换行符
                                [array removeAllObjects];
                                newLineIndex = rect.codepoint_index;
                            }
                        }
                    } else if (pEndIndex == -1) {
                        if (i == desPage.rowRectArray->count-1 && j == data->count) {
                            //本页最后一个字
                            pEndIndex = rect.codepoint_index;
                            break;
                        } else {
                            NSInteger rectAfterIndex = rect.codepoint_index + 1;
                            NSString *oneString = [self.attributedString.string substringWithRange:NSMakeRange(rectAfterIndex, 1)];
                            if ([oneString isEqualToString: @"\n"]) {
                                //下一个字是换行
                                pEndIndex = rect.codepoint_index;
                                break;
                            }
                        }
                    }
                    
                    CGRect onceRect = CGRectMake(rect.x, rect.y, rect.xx - rect.x, rect.yy - rect.y);
                    if (CGRectContainsPoint(onceRect, point) && pStartIndex == -1) {
                        pStartIndex = newLineIndex;
                    }
                    
                    [array addObject:[NSValue valueWithCGRect:onceRect]];
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
        
        if (pStartIndex >=0 && pEndIndex >=0) {
            //开始位置+1不包含第一个换行
            NSInteger startIndex = pStartIndex;
            NSInteger length = pEndIndex - pStartIndex;
#ifdef DEBUG
            NSLog(@"page:%@ 被选中的文字：%@", @(page),[self.attributedString.string substringWithRange:NSMakeRange(startIndex, length)]);
#endif
        }
        if (pStartIndex >=0) {
            return array;
        }
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
        return cachePage.image;
    }
    return nil;
}

- (void)toCacheWhenMoveTo:(NSInteger)pageNum
{
    if (pageNum >=0 && pageNum < [self totalPage] && self.cachedArray.count) {
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
            } else {
                if (!pageNumIsEqual){
                    [self toPreviousPage];
                }
            }
        } else if (index == self.cachedArray.count -1) {
            if (pageNum == [self totalPage]-1) {
            } else {
                if (!pageNumIsEqual){
                    [self toNextPage];
                }
            }
        }
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
    
#if kTLTXTPerformanceLog
    NSDate *date = [NSDate date];
#endif

#if kTLTXTPerformanceLog
    NSDate *bitmapStartDate = [NSDate date];
#endif
    TLTXTRowRectArray row_rect_array = NULL;
    uint8_t *bitmap = txt_worker_bitmap_one_page(&self->_worker,afterPageNum, &row_rect_array);
#if kTLTXTPerformanceLog
    NSLog(@"%s bitmap using time:%@", __func__, @(GetTimeDeltaValue(bitmapStartDate) ));
#endif
    if (bitmap != NULL) {
        
        dispatch_async(imageQueue, ^{
#if kTLTXTPerformanceLog
            NSDate *imageStartDate = [NSDate date];
#endif
            UIImage *image = [[self class] imageWith:bitmap width:self.pageSize.width height:self.pageSize.height scale:1];
            TLTXTCachePage *cachePage = [[TLTXTCachePage alloc] init];
            cachePage.pageNum = afterPageNum;
            cachePage.image = image;
            cachePage.rowRectArray = row_rect_array;
            cachePage.cursor = txt_worker_page_cursor_array_get(self.worker, afterPageNum);
            cachePage.beforeCursor = afterPageNum>0 ? txt_worker_page_cursor_array_get(self.worker, afterPageNum-1) : -1;
            NSMutableArray *array = [NSMutableArray arrayWithArray:self.cachedArray];
            [array removeObjectAtIndex:0];
            [array addObject:cachePage];
            
            self.cachedArray = array;
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
    
#if kTLTXTPerformanceLog
    NSDate *date = [NSDate date];
#endif

#if kTLTXTPerformanceLog
    NSDate *bitmapStartDate = [NSDate date];
#endif
    TLTXTRowRectArray row_rect_array = NULL;
    uint8_t *bitmap = txt_worker_bitmap_one_page(&self->_worker,afterPageNum, &row_rect_array);
#if kTLTXTPerformanceLog
    NSLog(@"%s bitmap using time:%@", __func__, @(GetTimeDeltaValue(bitmapStartDate) ));
#endif
    if (bitmap != NULL) {
        
        dispatch_async(imageQueue, ^{
#if kTLTXTPerformanceLog
            NSDate *imageStartDate = [NSDate date];
#endif
            UIImage *image = [[self class] imageWith:bitmap width:self.pageSize.width height:self.pageSize.height scale:1];
            TLTXTCachePage *cachePage = [[TLTXTCachePage alloc] init];
            cachePage.pageNum = afterPageNum;
            cachePage.image = image;
            cachePage.rowRectArray = row_rect_array;
            cachePage.cursor = txt_worker_page_cursor_array_get(self.worker, afterPageNum);
            cachePage.beforeCursor = afterPageNum>0 ? txt_worker_page_cursor_array_get(self.worker, afterPageNum-1) : -1;
            NSMutableArray *array = [NSMutableArray arrayWithArray:self.cachedArray];
            [array removeObjectAtIndex:2];
            [array insertObject:cachePage atIndex:0];
            self.cachedArray = array;
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
    free(bytes);
    UIImage *result = [UIImage imageWithCGImage:mainViewContentBitmapContext scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(mainViewContentBitmapContext);
    return result;
}

@end

@interface TLTXTCore()

@property(nonatomic)NSString        *coreId;
@property(nonatomic)NSMutableArray  *unitArray;

@end

@implementation TLTXTCore

+(void)load
{
    if (bitmapQueue == NULL) {
        bitmapQueue = dispatch_queue_create("TextLayout.bitmap", DISPATCH_QUEUE_SERIAL);
    }
    if (imageQueue == NULL) {
        imageQueue = dispatch_queue_create("TextLayout.image", DISPATCH_QUEUE_SERIAL);
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
                 cursorArray:(NSArray<NSNumber *> *)cursorArray
                   startPage:(NSInteger)pageNum
{
    TLTXTCoreUnit *unit = [[TLTXTCoreUnit alloc] init];
    unit.drawDelegate = self.drawDelegate;
    [self.unitArray addObject:unit];
    [unit resetAttributedString:aString pageSize:size cursorArray:cursorArray startPage:pageNum];
}

- (void)fillAttributedString:(TLAttributedString *)aString
                    pageSize:(CGSize)size
                 cursorArray:(NSArray<NSNumber *> *)cursorArray
{
    TLTXTCoreUnit *unit = [[TLTXTCoreUnit alloc] init];
    unit.drawDelegate = self.drawDelegate;
    [self.unitArray addObject:unit];
    [unit resetAttributedString:aString pageSize:size cursorArray:cursorArray];
}

- (NSArray<NSValue *> *_Nullable)paragraphStartEnd:(NSInteger)page point:(CGPoint)point textId:(nonnull NSString *)textId
{
    TLTXTCoreUnit *unit = [self unitWithTextId:textId];
    return [unit paragraphStartEnd:page point:point];
}

- (UIImage *_Nullable)onlyCachedImageWithPageNum:(NSInteger)pageNum textId:(nonnull NSString *)textId
{
    TLTXTCoreUnit *unit = [self unitWithTextId:textId];
    return [unit onlyCachedImageWithPageNum:pageNum];
}

- (void)firstTimeDraw:(BOOL)needsPaging startPage:(NSInteger)pageNum textId:(nonnull NSString *)textId
{
    TLTXTCoreUnit *unit = [self unitWithTextId:textId];
    [unit firstTimeDraw:needsPaging startPage:pageNum];
}

- (void)toCacheWhenMoveTo:(NSInteger)pageNum textId:(nonnull NSString *)textId
{
    TLTXTCoreUnit *unit = [self unitWithTextId:textId];
    [unit toCacheWhenMoveTo:pageNum];
}

- (void)toCacheWhenMoveTo:(NSInteger)pageNum textId:(NSString *)textId whetherEnd:(BOOL*)whetherEnd
{
    TLTXTCoreUnit *unit = [self unitWithTextId:textId];
    if (pageNum == [unit totalPage]-1) {
        if (whetherEnd) {
            *whetherEnd = YES;
        }
    }
    [unit toCacheWhenMoveTo:pageNum];
}

+ (NSArray<NSNumber *> *)oncePaging:(TLAttributedString *)aString pageSize:(CGSize)pageSize endPageHeight:(CGFloat*)height
{
    return [TLTXTPageHelper oncePaging:aString pageSize:pageSize endPageHeight:height];
}

#pragma mark- Private methods

- (TLTXTCoreUnit *)unitWithTextId:(nonnull NSString *)textId
{
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
                    cursorArray:(NSArray<NSNumber *> *)cursorArray
                         coreId:(NSString *)coreId
{
    //TEST
    NSLog(@"%s size%@", __FUNCTION__, @(size));
    //TEST END
    TLTXTCore *core = [self coreWithId:coreId];
    if (!core) {
        core = [[TLTXTCore alloc] init];
        core.coreId = coreId;
        [self.coreArray addObject:core];
    }
    [core fillAttributedString:aString pageSize:size cursorArray:cursorArray];
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

@end
