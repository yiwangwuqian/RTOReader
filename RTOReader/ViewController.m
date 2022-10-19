//
//  ViewController.m
//  OpenGLESFreeTypeDemo
//
//  Created by guohaoyang on 2019/11/6.
//  Copyright © 2019 guohaoyang. All rights reserved.
//

#import "ViewController.h"
#import "RTOReadView.h"
#import "RTOFontManager.h"

@interface ViewController ()
@property(nonatomic)RTOReadView*    readView;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor lightGrayColor];
    
    NSString *fontPath = [RTOFontManager systemFontPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:fontPath]) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [RTOFontManager configSystemFont];
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
