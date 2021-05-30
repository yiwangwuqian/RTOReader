//
//  AppDelegate.m
//  RTOReader
//
//  Created by ghy on 2020/3/25.
//  Copyright © 2020 ghy. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate
@synthesize window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window = window;
    ViewController *controller = [[ViewController alloc] init];
    window.rootViewController = controller;
    [window makeKeyAndVisible];
    
    return YES;
}

@end
