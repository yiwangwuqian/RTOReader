//
//  ViewController.m
//  OpenGLESFreeTypeDemo
//
//  Created by guohaoyang on 2019/11/6.
//  Copyright © 2019 guohaoyang. All rights reserved.
//

#import "ViewController.h"
#import "RTOReadContentViewController.h"

@interface ViewController ()

@property(nonatomic)UIButton    *button;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor lightGrayColor];
    
    CGFloat buttonWidth = 100;
    _button = [[UIButton alloc] initWithFrame:CGRectMake((CGRectGetWidth(self.view.bounds) - buttonWidth)/2, 100, buttonWidth, 40)];
    [_button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    _button.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:_button];
    [_button setTitle:@"打开" forState:UIControlStateNormal];
    [_button addTarget:self action:@selector(pressedOpenButton) forControlEvents:UIControlEventTouchUpInside];
}

- (void)pressedOpenButton
{
    RTOReadContentViewController *controller = [[RTOReadContentViewController alloc] init];
    [self presentViewController:controller animated:YES completion:NULL];
}

@end
