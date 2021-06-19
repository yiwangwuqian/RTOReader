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
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedView)];
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

- (void)tappedView
{
    [self toNextPage];
}

- (void)toNextPage
{
    CGFloat drawWidth = CGRectGetWidth(self.bounds) * [UIScreen mainScreen].scale;
    CGFloat drawHeight = CGRectGetHeight(self.bounds)  * [UIScreen mainScreen].scale;
    if (_worker == NULL) {
        char *content = "郭襄见前後都出现了僧人，秀眉深蹙，急道：「你们两个婆婆妈妈，没点男子汉气概！到底走不走？」张君宝道：「师父，郭姑娘一片好意──」</p><p>便在此时，下面边门中又窜出四名黄衣僧人，飕飕飕的奔上坡来，手中都没兵器，但身法迅捷，衣襟带风，武功颇为了得。郭襄见这般情势，便想单独脱身亦已不能，索性凝气卓立，静观其变。当先一名僧人奔到离她四丈之处，朗声说道：「罗汉堂首座尊师传谕：着来人放下兵刃，在山下一苇亭中陈明详情，听由法谕。」郭襄冷笑道：「少林寺的大和尚官派十足，官腔打得倒好听。请问各位大和尚做的是大宋皇帝的官儿呢，还是做蒙古皇帝的官？」</p><p>这时淮水以北，大宋国土均已沦陷，少林寺所在之地自也早归蒙古该管，只是蒙古大军连年进攻襄阳不克，忙於调兵遣将，也无余力来理会少林寺观的事，因此少林寺一如其旧，与前并无不同。那僧人听郭襄讥刺之言甚是厉害，不由得脸上一红，心中也觉对外人下令传谕有些不妥，合十说道：「不知女施主何事光临敝寺，且请放下兵刃，赴山下一苇亭中奉茶说话。」</p><p>郭襄听他语转和缓，便想乘此收蓬，说道：「你们不让我进寺，我便希罕了？";
        txt_worker_create(&_worker, content, drawWidth, drawHeight);
    }
    uint8_t *bitmap = txt_worker_bitmap_onepage(&_worker);
    _imageView.image = [[self class] imageWith:bitmap width:drawWidth height:drawHeight scale:1];
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
                desBytes[index*componentsCount+3] = 255;
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
                                                    kCGImageAlphaNoneSkipLast); // Bitmap info flags
    CGImageRef mainViewContentBitmapContext = CGBitmapContextCreateImage(contextRef);
    CGContextRelease(contextRef);
    free(desBytes);
    free(bytes);
    UIImage *result = [UIImage imageWithCGImage:mainViewContentBitmapContext scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(mainViewContentBitmapContext);
    return result;
}

@end
