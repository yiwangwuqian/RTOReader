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

    /*
    NSLog(@"%s", __FUNCTION__);
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self test];
    });
     */
}

- (void)test
{
    for (NSInteger i = 0; i<50000; i++) {
        [self toTest:i];
    }
}

- (void)toTest:(NSInteger)index
{
    //经过验证信号是可以阻塞当前执行线程的
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"%s index:%@", __FUNCTION__, @(index));
        dispatch_semaphore_signal(semaphore);
    });
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

@end
