//
//  RTOReadView.m
//  RTOReader
//
//  Created by ghy on 2021/6/2.
//  Copyright © 2021 ghy. All rights reserved.
//

#import "RTOReadView.h"
#include "esUtil.h"

#import "RTOTXTWorker.h"

#include <sys/stat.h>
#include <sys/mman.h>

void yw_file_content(const char *path, char** content,size_t *content_len)
{
    struct stat fdstat;
    stat(path, &fdstat);
    char *buf = NULL;
    size_t buf_size;
    
    int fd;
    fd = open(path, O_RDONLY);
    /* set buffer size */
    buf_size = fdstat.st_size;
    
    /* allocate the buffer storage */
    if (buf_size > 0) {
        buf = mmap(NULL, buf_size, PROT_READ, MAP_SHARED, fd, 0);
        if (buf == MAP_FAILED) {
            close(fd);
            return;
        }
        *content = buf;
        if (content_len) {
            *content_len = buf_size;
        }
    }
}

@interface RTOReadView()

@property(nonatomic)UIImageView*    imageView;
@property(nonatomic)RTOTXTWorker    worker;

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
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (!CGRectEqualToRect(_imageView.frame, self.bounds)) {
        _imageView.frame = self.bounds;
        
        [self toNextPage];
    }
}

- (void)tappedView:(UITapGestureRecognizer *)sender
{
    CGPoint point = [sender locationInView:sender.view];
    CGFloat width = CGRectGetWidth(self.frame);
    
    bool contains = false;
    uint32_t code_point = txt_worker_codepoint_at(&_worker, point.x * [UIScreen mainScreen].scale, point.y * [UIScreen mainScreen].scale, &contains);
    if (contains) {
        [[self class] convertCodePoint:code_point];
    }
    
    if (point.x < width*0.33) {
        [self toPreviousPage];
    } else if (point.x > width*0.67) {
        [self toNextPage];
    }
}

- (void)toNextPage
{
    CGFloat drawWidth = CGRectGetWidth(self.bounds) * [UIScreen mainScreen].scale;
    CGFloat drawHeight = CGRectGetHeight(self.bounds)  * [UIScreen mainScreen].scale;
    if (_worker == NULL) {
        char *content;
        yw_file_content([self.filePath cStringUsingEncoding:NSUTF8StringEncoding], &content, NULL);
        txt_worker_create(&_worker, content, drawWidth, drawHeight);
    }
    uint8_t *bitmap = txt_worker_bitmap_next_page(&_worker);
    if (bitmap != NULL) {
        _imageView.image = [[self class] imageWith:bitmap width:drawWidth height:drawHeight scale:1];
    }
}

- (void)toPreviousPage
{
    CGFloat drawWidth = CGRectGetWidth(self.bounds) * [UIScreen mainScreen].scale;
    CGFloat drawHeight = CGRectGetHeight(self.bounds)  * [UIScreen mainScreen].scale;
    uint8_t *bitmap = txt_worker_bitmap_previous_page(&_worker);
    if (bitmap != NULL) {
        _imageView.image = [[self class] imageWith:bitmap width:drawWidth height:drawHeight scale:1];
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
    if (two == 0) {
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
        //加注释的是按照utf8编码加了前缀的，不知道为什么错了
//        Byte byteData[] = {0xf0 + ((two>>2)&0x7), 0x80+ ((three>>4)&0xf) + ((two<<4)&0x30), 0x80+ ((three<<2)&0x3c) + ((four>>6)&0x3), 0x80+(four&0x3f)};
        Byte byteData[] = {one,two,three,four};
        result = [[NSString alloc] initWithData:[NSData dataWithBytes:byteData length:sizeof(byteData)] encoding:NSUTF8StringEncoding];
    }
    NSLog(@"点选结果是:%@", result);
    NSLog(@"%x %x %x %x code_point:%x", one, two, three, four, code_point);
    return result;
}

@end
