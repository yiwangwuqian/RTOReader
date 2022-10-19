//
//  RTOReadView.m
//  RTOReader
//
//  Created by ghy on 2021/6/2.
//  Copyright © 2021 ghy. All rights reserved.
//

#import "RTOReadView.h"

#import "RTOTXTWorker.h"
#import "FileWrapper.h"

#import "RTOReadSelectionView.h"
#import "GMenuController.h"
#include "TXTUtil.h"

@interface RTOReadView()

@property(nonatomic)UIImageView*    imageView;
@property(nonatomic)RTOTXTWorker    worker;

@property(nonatomic)RTOReadSelectionView*   selectionView;
@property(nonatomic)NSNumber*               selectionSNumber;
@property(nonatomic)NSNumber*               selectionENumber;

@end

@implementation RTOReadView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupSubviews];
    }
    return self;
}

- (void)setupSubviews
{
    if (!_imageView) {
        _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        [self addSubview:_imageView];
    }
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedView:)];
    [self addGestureRecognizer:tapRecognizer];
    
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pannedView:)];
    [self addGestureRecognizer:panRecognizer];
}

- (UIView *)selectionView
{
    if (!_selectionView) {
        _selectionView = [[RTOReadSelectionView alloc] initWithFrame:self.bounds];
        [self addSubview:_selectionView];
    }
    return _selectionView;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (!CGRectEqualToRect(_imageView.frame, self.bounds)) {
        _imageView.frame = self.bounds;
        
        [self toNextPage];
    }
}

- (void)pressedCopyButton
{
    size_t count;
    uint32_t *code_points = txt_worker_codepoint_in_range(&_worker, [self.selectionSNumber integerValue], [self.selectionENumber integerValue], &count);
    if (code_points) {
        [UIPasteboard generalPasteboard].string = [[self class] convertCodePoints:code_points count:count];
    }
    [[GMenuController sharedMenuController] setMenuVisible:NO];
    self.selectionView.rectArray = nil;
}

- (void)tappedView:(UITapGestureRecognizer *)sender
{
    CGPoint point = [sender locationInView:sender.view];
    CGFloat width = CGRectGetWidth(self.frame);
    
    if (point.x < width*0.33) {
        [self toPreviousPage];
    } else if (point.x > width*0.67) {
        [self toNextPage];
    } else {
        RTOTXTRect contains = NULL;
        uint32_t code_point = txt_worker_codepoint_at(&_worker, point.x * [UIScreen mainScreen].scale, point.y * [UIScreen mainScreen].scale, &contains);
        if (contains) {
            [[self class] convertCodePoint:code_point];
            
            int x,y,xx,yy;
            txt_rect_values(&contains, &x, &y, &xx, &yy);
            free(contains);
            if (!self.selectionView.superview) {
                [self addSubview:self.selectionView];
            }
            CGFloat scale = [UIScreen mainScreen].scale;
            self.selectionView.rectArray = @[[NSValue valueWithCGRect:CGRectMake(x/scale, y/scale, (xx-x)/scale, (yy-y)/scale)]];
        }
    }
}

- (void)pannedView:(UIPanGestureRecognizer *)sender
{
    static NSValue *lastPoint = NULL;
    CGPoint nPoint = [sender locationInView:sender.view];
    switch (sender.state) {
        case UIGestureRecognizerStateBegan:
            lastPoint = [NSValue valueWithCGPoint:nPoint];
            break;
        case UIGestureRecognizerStateChanged:
        case UIGestureRecognizerStateRecognized:
        {
            RTOTXTRectArray rect_array=NULL;
            CGPoint point = [lastPoint CGPointValue];
            CGFloat scale = [UIScreen mainScreen].scale;
            size_t s_index;
            size_t e_index;
            txt_worker_rect_array_from(&_worker, &rect_array, point.x*scale, point.y*scale, nPoint.x*scale, nPoint.y*scale, &s_index, &e_index);
            self.selectionSNumber = @(s_index);
            self.selectionENumber = @(e_index);
            
            if (rect_array) {
                NSMutableArray *array = [NSMutableArray array];
                for (int i=0; i<txt_worker_rect_array_get_count(&rect_array); i++) {
                    int x,y,xx,yy;
                    RTOTXTRect one_rect = txt_worker_rect_array_object_at(&rect_array, i);
                    txt_rect_values(&one_rect, &x, &y, &xx, &yy);
                    [array addObject:[NSValue valueWithCGRect:CGRectMake(x/scale, y/scale, (xx-x)/scale, (yy-y)/scale)]];
                }
                
                if (!self.selectionView.superview) {
                    [self addSubview:self.selectionView];
                }
                
                self.selectionView.rectArray = array;
            }
            if (rect_array) {
                txt_rect_array_destroy(&rect_array);
            }
            
            if (sender.state == UIGestureRecognizerStateRecognized) {
                lastPoint = NULL;
                
                GMenuItem *item2 = [[GMenuItem alloc] initWithTitle:@"复制" target:self action:@selector(pressedCopyButton)];
                NSArray* arr1 = @[item2];
                [[GMenuController sharedMenuController] setMenuItems:arr1];
                [[GMenuController sharedMenuController] setTargetRect:[self.selectionView.rectArray.firstObject CGRectValue] inView:self.selectionView];
                [[GMenuController sharedMenuController] setMenuVisible:YES];
                [GMenuController sharedMenuController].menuViewContainer.hasAutoHide = YES;
            }
        }
            break;
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            lastPoint = NULL;
            break;
        default:
            break;
    }
}

- (void)toNextPage
{
    CGFloat drawWidth = CGRectGetWidth(self.bounds) * [UIScreen mainScreen].scale;
    CGFloat drawHeight = CGRectGetHeight(self.bounds)  * [UIScreen mainScreen].scale;
    if (_worker == NULL) {
        char *content;
        txt_file_content([self.filePath cStringUsingEncoding:NSUTF8StringEncoding], &content, NULL);
        txt_worker_create(&_worker, content, drawWidth, drawHeight);
    }
    uint8_t *bitmap = txt_worker_bitmap_next_page(&_worker);
    if (bitmap != NULL) {
        _imageView.image = [[self class] imageWith:bitmap width:drawWidth height:drawHeight scale:1];
        [[self class] turnPageToNext:YES forView:_imageView];
        self.selectionView.rectArray = nil;
    }
}

- (void)toPreviousPage
{
    CGFloat drawWidth = CGRectGetWidth(self.bounds) * [UIScreen mainScreen].scale;
    CGFloat drawHeight = CGRectGetHeight(self.bounds)  * [UIScreen mainScreen].scale;
    uint8_t *bitmap = txt_worker_bitmap_previous_page(&_worker);
    if (bitmap != NULL) {
        _imageView.image = [[self class] imageWith:bitmap width:drawWidth height:drawHeight scale:1];
        [[self class] turnPageToNext:NO forView:_imageView];
        self.selectionView.rectArray = nil;
    }
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

+ (void)turnPageToNext:(BOOL)next forView:(UIView *) view
{
    CATransition *animation = [CATransition animation];
    animation.duration = 1.0;
    //push pageCurl reveal moveIn
    animation.type = @"pageCurl";
    animation.subtype = next ? kCATransitionFromRight : kCATransitionFromLeft;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [view.layer addAnimation:animation forKey:@"animation"];
}

@end
