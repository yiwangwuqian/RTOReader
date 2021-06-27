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

@interface RTOReadView()

@property(nonatomic)UIImageView*    imageView;
@property(nonatomic)NSUInteger      lastWordsIndex;
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
        char *content = "北京的某片地区座落着大大小小的工厂和高矮不一的烟囱，它们为振兴民族工业和提高空气污染指数做出了巨大贡献。而今天，它们已处于瘫痪状态，等待着陆续被拆除，颇像地主家的大老婆，失去了生机与活力。一座座高耸入云的现代化建筑取而代之，在此处拔地而起，犹如刚过门的小媳妇，倍受青睐。大烟囱和摩登大厦鳞次栉比，交相辉映，挺立在北京市上空，构成海拔最高点。如若谁想鸟瞰北京城，可以喝着咖啡端坐在这些写字楼高层的窗前，或是拿着扫帚爬到烟囱顶端去打扫烟灰。\n我的学校便坐落在这些工厂和写字楼的包围之中，它就是北京XX大学，简称北X大，以“四大染缸”的美誉扬名北京，尤其在高中学生中间流传甚广，但每年仍会有愈来愈多的高中毕业生因扩招而源源不断地涌向这里，丝毫看不出计划生育作为一项基本国策已在北京实施多年的迹象，倒是录取分数线越降越低，以至让我产生了“这还是考大学吗”的疑惑。\n这所学校诞生过工程师、厂长、教授、总经理、小商贩、会计师、出纳员、网站CEO、小偷、警察、嫖客、妓女、诗人、作家、摇滚乐手、音乐制作人、画家、外籍华人、运动员、记者、骗子、白痴、技术员、建筑师、传销商、卖保险的、包工头、科长、处长和游手好闲职业者，惟独没有政治要员，这也许同学校的环境有关，但更多因素源于学生自身，但凡考到这里的学生，全无一例的没有政治头脑，此类学生早已坐到了清华、北大和人大的教室里。";
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

@end
