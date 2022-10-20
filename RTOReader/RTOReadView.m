//
//  RTOReadView.m
//  RTOReader
//
//  Created by ghy on 2021/6/2.
//  Copyright © 2021 ghy. All rights reserved.
//

#define GetTimeDeltaValue(a) [[NSDate date] timeIntervalSince1970] - [(a) timeIntervalSince1970]

#import "RTOReadView.h"

#import <TextLayout/TLTXTCore.h>

#import "RTOReadSelectionView.h"
#import "GMenuController.h"

@interface RTOReadView()<TLTXTCoreDrawDelegate>

@property(nonatomic)TLTXTCore       *txtCore;
@property(nonatomic)UIImageView*    imageView;
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
//    size_t count;
//    uint32_t *code_points = txt_worker_codepoint_in_range(&_worker, [self.selectionSNumber integerValue], [self.selectionENumber integerValue], &count);
//    if (code_points) {
//        [UIPasteboard generalPasteboard].string = [[self class] convertCodePoints:code_points count:count];
//    }
//    [[GMenuController sharedMenuController] setMenuVisible:NO];
//    self.selectionView.rectArray = nil;
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
//        RTOTXTRect contains = NULL;
//        uint32_t code_point = txt_worker_codepoint_at(&_worker, point.x * [UIScreen mainScreen].scale, point.y * [UIScreen mainScreen].scale, &contains);
//        if (contains) {
//            [[self class] convertCodePoint:code_point];
//
//            int x,y,xx,yy;
//            txt_rect_values(&contains, &x, &y, &xx, &yy);
//            free(contains);
//            if (!self.selectionView.superview) {
//                [self addSubview:self.selectionView];
//            }
//            CGFloat scale = [UIScreen mainScreen].scale;
//            self.selectionView.rectArray = @[[NSValue valueWithCGRect:CGRectMake(x/scale, y/scale, (xx-x)/scale, (yy-y)/scale)]];
//        }
    }
}

- (void)pannedView:(UIPanGestureRecognizer *)sender
{
//    static NSValue *lastPoint = NULL;
//    CGPoint nPoint = [sender locationInView:sender.view];
//    switch (sender.state) {
//        case UIGestureRecognizerStateBegan:
//            lastPoint = [NSValue valueWithCGPoint:nPoint];
//            break;
//        case UIGestureRecognizerStateChanged:
//        case UIGestureRecognizerStateRecognized:
//        {
//            RTOTXTRectArray rect_array=NULL;
//            CGPoint point = [lastPoint CGPointValue];
//            CGFloat scale = [UIScreen mainScreen].scale;
//            size_t s_index;
//            size_t e_index;
//            txt_worker_rect_array_from(&_worker, &rect_array, point.x*scale, point.y*scale, nPoint.x*scale, nPoint.y*scale, &s_index, &e_index);
//            self.selectionSNumber = @(s_index);
//            self.selectionENumber = @(e_index);
//
//            if (rect_array) {
//                NSMutableArray *array = [NSMutableArray array];
//                for (int i=0; i<txt_worker_rect_array_get_count(&rect_array); i++) {
//                    int x,y,xx,yy;
//                    RTOTXTRect one_rect = txt_worker_rect_array_object_at(&rect_array, i);
//                    txt_rect_values(&one_rect, &x, &y, &xx, &yy);
//                    [array addObject:[NSValue valueWithCGRect:CGRectMake(x/scale, y/scale, (xx-x)/scale, (yy-y)/scale)]];
//                }
//
//                if (!self.selectionView.superview) {
//                    [self addSubview:self.selectionView];
//                }
//
//                self.selectionView.rectArray = array;
//            }
//            if (rect_array) {
//                txt_rect_array_destroy(&rect_array);
//            }
//
//            if (sender.state == UIGestureRecognizerStateRecognized) {
//                lastPoint = NULL;
//
//                GMenuItem *item2 = [[GMenuItem alloc] initWithTitle:@"复制" target:self action:@selector(pressedCopyButton)];
//                NSArray* arr1 = @[item2];
//                [[GMenuController sharedMenuController] setMenuItems:arr1];
//                [[GMenuController sharedMenuController] setTargetRect:[self.selectionView.rectArray.firstObject CGRectValue] inView:self.selectionView];
//                [[GMenuController sharedMenuController] setMenuVisible:YES];
//                [GMenuController sharedMenuController].menuViewContainer.hasAutoHide = YES;
//            }
//        }
//            break;
//        case UIGestureRecognizerStateCancelled:
//        case UIGestureRecognizerStateFailed:
//            lastPoint = NULL;
//            break;
//        default:
//            break;
//    }
}

- (void)toNextPage
{
#if DEBUG
    NSDate *date = [NSDate date];
#endif
    
    if (_txtCore == nil) {
        self.txtCore = [[TLTXTCore alloc] init];
        self.txtCore.drawDelegate = self;
        CGFloat drawWidth = CGRectGetWidth(self.bounds) * [UIScreen mainScreen].scale;
        CGFloat drawHeight = CGRectGetHeight(self.bounds)  * [UIScreen mainScreen].scale;
        [self.txtCore resetFilePath:self.filePath pageSize:CGSizeMake(drawWidth, drawHeight)];
    }
    
    UIImage *image = _imageView.image == nil ? [self.txtCore currentPageImage] : [self.txtCore toNextPageOnce];
#if DEBUG
    NSDate *imageAssignDate = [NSDate date];
#endif
    _imageView.image = image;
#if DEBUG
    NSLog(@"%s image assign using time:%f", __func__, GetTimeDeltaValue(imageAssignDate));
#endif
    [[self class] turnPageToNext:YES forView:_imageView];
    self.selectionView.rectArray = nil;
    
#if DEBUG
    NSLog(@"%s using time:%f", __func__, GetTimeDeltaValue(date));
#endif
}

- (void)toPreviousPage
{
    _imageView.image = [self.txtCore toPreviousPageOnce];
    [[self class] turnPageToNext:NO forView:_imageView];
    self.selectionView.rectArray = nil;
}

+ (void)turnPageToNext:(BOOL)next forView:(UIView *) view
{
    /*
    
    CATransition *animation = [CATransition animation];
    animation.duration = 1.0;
    //push pageCurl reveal moveIn
    animation.type = @"pageCurl";
    animation.subtype = next ? kCATransitionFromRight : kCATransitionFromLeft;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [view.layer addAnimation:animation forKey:@"animation"];
     
     */
}

- (void)firstPageEnd
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self toNextPage];
    });
}

@end
