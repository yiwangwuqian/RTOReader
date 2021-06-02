//
//  ViewController.m
//  OpenGLESFreeTypeDemo
//
//  Created by guohaoyang on 2019/11/6.
//  Copyright © 2019 guohaoyang. All rights reserved.
//

#import "ViewController.h"
#import "RTOReadView.h"

@interface ViewController ()
@property(nonatomic)RTOReadView*    readView;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor lightGrayColor];
    
    if (!_readView) {
        _readView = [[RTOReadView alloc] init];
        [self.view addSubview:_readView];
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    CGFloat imageWidth = CGRectGetWidth(self.view.frame);
    CGFloat imageHeight = CGRectGetHeight(self.view.frame);
    if (CGRectEqualToRect(_readView.frame, CGRectZero)) {
        CGRect frame = self.view.bounds;
        if (@available(iOS 11.0, *)) {
            UIEdgeInsets insets = self.view.window.safeAreaInsets;
            imageHeight = CGRectGetHeight(self.view.frame) - insets.top - insets.bottom;
            frame = CGRectMake(0, insets.top, imageWidth, imageHeight);
        }
        _readView.frame = frame;
    }
}

@end
