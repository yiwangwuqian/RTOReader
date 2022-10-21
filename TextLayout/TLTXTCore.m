//
//  TLTXTCore.m
//  TextLayout
//
//  Created by guohy on 2022/10/20.
//  Copyright © 2022 ghy. All rights reserved.
//

#define GetTimeDeltaValue(a) [[NSDate date] timeIntervalSince1970] - [(a) timeIntervalSince1970]

#import "TLTXTCore.h"
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

#import "TLTXTWorker.h"
#import "FileWrapper.h"
#import "TLTXTUtil.h"

@interface TLTXTCore()

@property(nonatomic)NSString            *filePath;
@property(nonatomic)CGSize              pageSize;
@property(nonatomic)TLTXTWorker         worker;

@property(nonatomic)dispatch_queue_t    bitmapQueue;//bitmap绘制专用
@property(nonatomic)dispatch_queue_t    imageQueue;//UIImage创建专用

@property(nonatomic)NSMutableArray      *array;//存放生成的UIImage对象
@property(nonatomic)NSInteger           pageNum;//页码翻页时的判断使用

/**
 *以下两个属性 内容的绘制和生成UIImage都是异步的，翻页时确保上一个操作完成了
 */
@property(nonatomic)dispatch_semaphore_t    nextPageSemaphore;
@property(nonatomic)dispatch_semaphore_t    previousPageSemaphore;
@end

@implementation TLTXTCore

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
        _bitmapQueue = dispatch_queue_create("TextLayout.bitmap", DISPATCH_QUEUE_SERIAL);
        _imageQueue = dispatch_queue_create("TextLayout.image", DISPATCH_QUEUE_SERIAL);
        _array = [[NSMutableArray alloc] init];
        _pageNum = -1;
    }
    return self;
}

- (void)resetFilePath:(NSString *)path pageSize:(CGSize)size
{
    if (!path) {
        return;
    } else if (CGSizeEqualToSize(size, CGSizeZero)) {
        return;
    }
    
    self.filePath = path;
    self.pageSize = size;
    
    if (_worker) {
        //TODO: 销毁_worker
        _worker = NULL;
    }
    
    char *content;
    txt_file_content([self.filePath cStringUsingEncoding:NSUTF8StringEncoding], &content, NULL);
    txt_worker_create(&_worker, content, size.width, size.height);
    
    self.pageNum = -1;
    [self firstTimeDraw];
}

- (void)firstTimeDraw
{
    dispatch_async(self.bitmapQueue, ^{
#if DEBUG
        NSDate *pagingDate = [NSDate date];
#endif
        txt_worker_data_paging(&self->_worker);
#if DEBUG
        NSLog(@"%s paging using time:%@", __func__, @(GetTimeDeltaValue(pagingDate) ));
#endif
        //调用三次对应绘制3页
        for (NSInteger i=0; i<3; i++) {
            uint8_t *bitmap = txt_worker_bitmap_next_page(&self->_worker);
            if (bitmap != NULL) {
                
                dispatch_async(self.imageQueue, ^{
                    UIImage *image = [[self class] imageWith:bitmap width:self.pageSize.width height:self.pageSize.height scale:1];
                    NSInteger arrayCount = self.array.count;
                    [self.array addObject:image];
                    
                    if (arrayCount == 0 && self.drawDelegate) {
                        self.pageNum = 0;
                        [self.drawDelegate firstPageEnd];
                    }
                });
                
            }
        }
    });
}

- (UIImage *)currentPageImage
{
    NSInteger arrayCount = self.array.count;
    if (arrayCount == 3) {
        return self.array[1];
    }
    return self.array.firstObject;
}

- (UIImage *)toPreviousPageOnce
{
    [self toPreviousPage];
    return self.array.firstObject;
}

- (UIImage *)toNextPageOnce
{
    if (txt_worker_next_able(&_worker)) {
        [self toNextPage];
        return self.array.lastObject;
    } else {
        return nil;
    }
}

- (UIImage *)imageWithPageNum:(NSInteger)pageNum
{
    NSInteger page = txt_worker_current_page(&_worker);
    if (pageNum < 2 && page < 3) {
        
        if (pageNum == 0) {
            return self.array.firstObject;
        } else if (pageNum == 1) {
            return self.array[1];
        }
        
    }
    return self.array.firstObject;
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
    self.nextPageSemaphore = dispatch_semaphore_create(0);
    
    dispatch_async(self.bitmapQueue, ^{
    
#if DEBUG
    NSDate *date = [NSDate date];
#endif

#if DEBUG
    NSDate *bitmapStartDate = [NSDate date];
#endif
    uint8_t *bitmap = txt_worker_bitmap_next_page(&self->_worker);
#if DEBUG
    NSLog(@"%s bitmap using time:%@", __func__, @(GetTimeDeltaValue(bitmapStartDate) ));
#endif
    if (bitmap != NULL) {
        
        dispatch_async(self.imageQueue, ^{
#if DEBUG
            NSDate *imageStartDate = [NSDate date];
#endif
            UIImage *image = [[self class] imageWith:bitmap width:self.pageSize.width height:self.pageSize.height scale:1];
            NSMutableArray *array = [NSMutableArray arrayWithArray:self.array];
            [array removeObjectAtIndex:0];
            [array addObject:image];
            self.array = array;
#if DEBUG
            NSLog(@"%s image create using time:%@", __func__, @(GetTimeDeltaValue(imageStartDate) ));
#endif
            
#if DEBUG
    NSLog(@"%s using time:%@", __func__, @(GetTimeDeltaValue(date) ));
#endif
            dispatch_semaphore_signal(self.nextPageSemaphore);
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
    self.previousPageSemaphore = dispatch_semaphore_create(0);
    dispatch_async(self.bitmapQueue, ^{
    
#if DEBUG
    NSDate *date = [NSDate date];
#endif

#if DEBUG
    NSDate *bitmapStartDate = [NSDate date];
#endif
    uint8_t *bitmap = txt_worker_bitmap_previous_page(&self->_worker);
#if DEBUG
    NSLog(@"%s bitmap using time:%@", __func__, @(GetTimeDeltaValue(bitmapStartDate) ));
#endif
    if (bitmap != NULL) {
        
        dispatch_async(self.imageQueue, ^{
#if DEBUG
            NSDate *imageStartDate = [NSDate date];
#endif
            UIImage *image = [[self class] imageWith:bitmap width:self.pageSize.width height:self.pageSize.height scale:1];
            NSMutableArray *array = [NSMutableArray arrayWithArray:self.array];
            [array removeObjectAtIndex:2];
            [array insertObject:image atIndex:0];
            self.array = array;
#if DEBUG
            NSLog(@"%s image create using time:%@", __func__, @(GetTimeDeltaValue(imageStartDate) ));
#endif
            
#if DEBUG
    NSLog(@"%s using time:%@", __func__, @(GetTimeDeltaValue(date) ));
#endif
            dispatch_semaphore_signal(self.previousPageSemaphore);
        });
            
    } else {
        dispatch_semaphore_signal(self.previousPageSemaphore);
    }
    });
}

+ (UIImage *)imageWith:(uint8_t *)bytes width:(CGFloat)bWidth height:(CGFloat)bHeight scale:(CGFloat)scale
{
    NSInteger componentsCount = 4;
    uint8_t *desBytes = calloc(bWidth*bHeight*4, sizeof(uint8_t));
    for (NSInteger x=0; x<bWidth; x++) {
        for (NSInteger y=0; y<bHeight; y++) {
            NSInteger index = y*bWidth+x;
            uint8_t value = bytes[index];
            if (value) {
                desBytes[index*componentsCount+3] = value;
            } else {
                desBytes[index*componentsCount] = 255;
                desBytes[index*componentsCount+1] = 255;
                desBytes[index*componentsCount+2] = 255;
                desBytes[index*componentsCount+3] = 255;
            }
        }
    }
    
    CGFloat width = bWidth;
    CGFloat height = bHeight;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef contextRef = CGBitmapContextCreate(desBytes,                 // Pointer to backing data
                                                    width,                       // Width of bitmap
                                                    height,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    width*componentsCount,              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big); // Bitmap info flags
    CGImageRef mainViewContentBitmapContext = CGBitmapContextCreateImage(contextRef);
    CGContextRelease(contextRef);
    free(desBytes);
    free(bytes);
    UIImage *result = [UIImage imageWithCGImage:mainViewContentBitmapContext scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(mainViewContentBitmapContext);
    return result;
}

+ (NSString *)convertCodePoint:(uint32_t)code_point
{
    uint8_t one = (code_point>>24)&0XFF;//按当前标准 这个字节忽略；只考虑后三个字节
    uint8_t two = (code_point>>16)&0XFF;
    uint8_t three = (code_point>>8)&0XFF;
    uint8_t four = code_point&0XFF;
    
    NSString *result = nil;
    if (one == 0 && two == 0) {
        if (three != 0) {
            if (three >= 8) {
                //三字节
                Byte byteData[] = {0xe0+((three>>4)&0xf), 0x80+ ((three<<2)&0x3c) + ((four>>6)&0x3), 0x80+(four&0x3f)};
                NSData *data = [NSData dataWithBytes:byteData length:sizeof(byteData)];
                result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            } else {
                //两字节
                Byte byteData[] = {0xc0+((three>>3)&0x1f), 0x80+(four&0x3f)};
                result = [[NSString alloc] initWithData:[NSData dataWithBytes:byteData length:sizeof(byteData)] encoding:NSUTF8StringEncoding];
            }
        } else {
            Byte byteData[] = {four};
            result = [[NSString alloc] initWithData:[NSData dataWithBytes:byteData length:sizeof(byteData)] encoding:NSUTF8StringEncoding];
        }
    } else {
        //四字节
        Byte byteData[] = {0xf0 + ((two>>2)&0x7), 0x80+ ((three>>4)&0xf) + ((two<<4)&0x30), 0x80+ ((three<<2)&0x3c) + ((four>>6)&0x3), 0x80+(four&0x3f)};
        result = [[NSString alloc] initWithData:[NSData dataWithBytes:byteData length:sizeof(byteData)] encoding:NSUTF8StringEncoding];
    }
    NSLog(@"点选结果是:%@", result);
    NSLog(@"%x %x %x %x code_point:%x", one, two, three, four, code_point);
    return result;
}

+ (NSData *)dataWithCodePoint:(uint32_t)code_point
{
    uint8_t one = (code_point>>24)&0XFF;
    uint8_t two = (code_point>>16)&0XFF;
    uint8_t three = (code_point>>8)&0XFF;
    uint8_t four = code_point&0XFF;
    
    NSData *data;
    if (one == 0 && two == 0) {
        if (three != 0) {
            if (three >= 8) {
                //三字节
                Byte byteData[] = {0xe0+((three>>4)&0xf), 0x80+ ((three<<2)&0x3c) + ((four>>6)&0x3), 0x80+(four&0x3f)};
                data = [NSData dataWithBytes:byteData length:sizeof(byteData)];
            } else {
                //两字节
                Byte byteData[] = {0xc0+((three>>3)&0x1f), 0x80+(four&0x3f)};
                data = [NSData dataWithBytes:byteData length:sizeof(byteData)];
            }
        } else {
            Byte byteData[] = {four};
            data = [NSData dataWithBytes:byteData length:sizeof(byteData)];
        }
    } else {
        //四字节
        Byte byteData[] = {0xf0 + ((two>>2)&0x7), 0x80+ ((three>>4)&0xf) + ((two<<4)&0x30), 0x80+ ((three<<2)&0x3c) + ((four>>6)&0x3), 0x80+(four&0x3f)};
        data = [NSData dataWithBytes:byteData length:sizeof(byteData)];
    }
    return data;
}

+ (NSString *)convertCodePoints:(uint32_t*)code_points count:(size_t)count
{
    NSMutableData *result = [NSMutableData data];
    for (size_t i=0; i<count; i++) {
        NSData *data = [self dataWithCodePoint:code_points[i]];
        [result appendData:data];
    }
    NSString *string = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
    return string;
}

@end
