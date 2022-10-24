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

@interface RTOReadView()<TLTXTCoreDrawDelegate,UIScrollViewDelegate>

@property(nonatomic)TLTXTCore       *txtCore;
@property(nonatomic)UIImageView*    imageView;
@property(nonatomic)RTOReadSelectionView*   selectionView;
@property(nonatomic)NSNumber*               selectionSNumber;
@property(nonatomic)NSNumber*               selectionENumber;

@property(nonatomic)UIScrollView*   scrollView;
@property(nonatomic)NSMutableArray* imageViewArray;
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
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        _scrollView.pagingEnabled = YES;
//        _scrollView.decelerationRate = 0.1;
        _scrollView.delegate = self;
        _scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        [self addSubview:_scrollView];
    }
    
    if (!_imageViewArray) {
        _imageViewArray = [[NSMutableArray alloc] init];
    }
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
    
    if (!CGRectEqualToRect(_scrollView.frame, self.bounds)) {
        _scrollView.frame = self.bounds;
        
        if (_txtCore == nil) {
            self.txtCore = [[TLTXTCore alloc] init];
            self.txtCore.drawDelegate = self;
            CGFloat drawWidth = CGRectGetWidth(self.bounds) * [UIScreen mainScreen].scale;
            CGFloat drawHeight = CGRectGetHeight(self.bounds)  * [UIScreen mainScreen].scale;
            [self.txtCore resetFilePath:self.filePath pageSize:CGSizeMake(drawWidth, drawHeight)];
        }
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
//    CGPoint point = [sender locationInView:sender.view];
//    CGFloat width = CGRectGetWidth(self.frame);
//
//    if (point.x < width*0.33) {
//        [self toPreviousPage];
//    } else if (point.x > width*0.67) {
//        [self toNextPage];
//    } else {
////        TLTXTRect contains = NULL;
////        uint32_t code_point = txt_worker_codepoint_at(&_worker, point.x * [UIScreen mainScreen].scale, point.y * [UIScreen mainScreen].scale, &contains);
////        if (contains) {
////            [[self class] convertCodePoint:code_point];
////
////            int x,y,xx,yy;
////            txt_rect_values(&contains, &x, &y, &xx, &yy);
////            free(contains);
////            if (!self.selectionView.superview) {
////                [self addSubview:self.selectionView];
////            }
////            CGFloat scale = [UIScreen mainScreen].scale;
////            self.selectionView.rectArray = @[[NSValue valueWithCGRect:CGRectMake(x/scale, y/scale, (xx-x)/scale, (yy-y)/scale)]];
////        }
//    }
    
//    NSArray *array = self.txtCore.currentRowRectArray;
//    if (array.count) {
//        if (!self.selectionView.superview) {
//            [self addSubview:self.selectionView];
//        }
//        self.selectionView.rectArray = self.txtCore.currentRowRectArray;
//    }
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
//            TLTXTRectArray rect_array=NULL;
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
//                    TLTXTRect one_rect = txt_worker_rect_array_object_at(&rect_array, i);
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
    
    UIImage *image = _imageView.image == nil ? [self.txtCore imageWithPageNum:0] : [self.txtCore toNextPageOnce];
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
        [self firstPageEndWork];
    });
}

- (void)firstPageEndWork
{
    NSInteger totalCount = self.txtCore.totalPage;
    CGSize contentSize = self.bounds.size;
    //横滑配置
    contentSize.width = contentSize.width * totalCount;
    
    //竖滑配置
//        contentSize.height = contentSize.height * totalCount;
    
    _scrollView.contentSize = contentSize;
    
    for (NSInteger i=0; i<totalCount; i++) {
        CGRect imageFrame = _scrollView.bounds;
        //横滑配置
        imageFrame.origin.x = i*CGRectGetWidth(_scrollView.frame);
        
        //竖滑配置
//            imageFrame.origin.y = i*CGRectGetHeight(_scrollView.frame);
        
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:imageFrame];
        [_scrollView addSubview:imageView];
        [_imageViewArray addObject:imageView];
    }
    
    UIImageView *imageView = self.imageViewArray.firstObject;
    imageView.image = [self.txtCore imageWithPageNum:0];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    static CGPoint lastContentOffset;
    CGPoint contentOffset = scrollView.contentOffset;
    
    //横滑配置
    if (contentOffset.x > 0) {
        NSInteger scrollWidth = scrollView.frame.size.width;
        NSInteger originX = contentOffset.x;
        NSInteger baseIndex = originX/scrollWidth;
        if (lastContentOffset.x < contentOffset.x) {
            //向右
            NSInteger index = baseIndex + (originX%scrollWidth > 0 ? 1 : 0);
                        
            if (index < self.imageViewArray.count) {
                //TEST
                NSLog(@"Now need prepare image for index:%@", @(index));
                //TEST END
                
                UIImageView *imageView = self.imageViewArray[index];
                imageView.image = [self.txtCore imageWithPageNum:index];
            }
        } else {
//            //向左
//            NSInteger index = baseIndex;
//
//            if (index >= 0) {
//                //TEST
//                NSLog(@"Now need prepare image for index:%@", @(index));
//                //TEST END
//
//                UIImageView *imageView = self.imageViewArray[index];
//                imageView.image = [self.txtCore imageWithPageNum:index];
//            }
        }
        lastContentOffset = contentOffset;
    }
    
    //竖滑配置
    /*
    if (contentOffset.y > 0) {
        
        if (lastContentOffset.y < contentOffset.y) {
            //向下
            NSInteger index = (contentOffset.y + scrollView.frame.size.height)/scrollView.frame.size.height;
            
            UIImageView *imageView = self.imageViewArray[index];
            if (imageView.image == nil) {
                imageView.image = [self.txtCore toNextPageOnce];
            }
        }
        lastContentOffset = contentOffset;
    }
    */
}

//- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
//{
//    if (decelerate) {
//        [scrollView setContentOffset:scrollView.contentOffset animated:NO];
//    }
//}

@end
