//
//  RTOReadContentViewController.m
//  RTOReader
//
//  Created by guohy on 2022/10/20.
//  Copyright © 2022 ghy. All rights reserved.
//

#import "RTOReadContentViewController.h"
#import "RTOReadView.h"
#import <TextLayout/TLFontManager.h>

@interface RTOReadContentViewController ()
@property(nonatomic)UIButton*       closeButton;
@property(nonatomic)RTOReadView*    readView;
@end

@implementation RTOReadContentViewController

- (void)dealloc
{
#ifdef DEBUG
    NSLog(@"%@ dealloc", self);
#endif
}

- (void)pressedCloseButton
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.automaticallyAdjustsScrollViewInsets = NO;
    self.view.backgroundColor = [UIColor whiteColor];
    
    _closeButton = [[UIButton alloc] init];
    [_closeButton setImage:[UIImage imageNamed:@"nav_icon_close"] forState:UIControlStateNormal];
    [_closeButton sizeToFit];
    CGRect closeFrame = _closeButton.frame;
    closeFrame.origin = CGPointMake(0, 20);
    closeFrame.size = CGSizeMake(closeFrame.size.width*2, closeFrame.size.height*2);
    _closeButton.frame = closeFrame;
    [_closeButton addTarget:self action:@selector(pressedCloseButton) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_closeButton];
    
    NSString *fontPath = [TLFontManager systemFontPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:fontPath]) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [TLFontManager configSystemFont];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setupReadView];
            });
        });
    } else {
        [self setupReadView];
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    if (_readView && CGRectEqualToRect(_readView.frame, CGRectZero)) {
        _readView.frame = [self readViewFrame];
    }
}

- (void)setupReadView
{
    if (!_readView) {
        _readView = [[RTOReadView alloc] init];
        _readView.filePath = [[NSBundle mainBundle] pathForResource:@"yitian1" ofType:@"txt"];
        [self.view addSubview:_readView];
        _readView.frame = [self readViewFrame];
    }
    
    [self.view bringSubviewToFront:_closeButton];
}

- (CGRect)readViewFrame
{
    CGFloat imageWidth = CGRectGetWidth(self.view.frame);
    CGFloat imageHeight = CGRectGetHeight(self.view.frame);

    CGRect frame = self.view.bounds;
    if (@available(iOS 11.0, *)) {
        UIEdgeInsets insets = self.view.window.safeAreaInsets;
        imageHeight = CGRectGetHeight(self.view.frame) - insets.top - insets.bottom;
        frame = CGRectMake(0, insets.top, imageWidth, imageHeight);
    }
    return frame;
}

@end
