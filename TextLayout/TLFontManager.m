//
//  TLFontManager.m
//  RTOReader
//
//  Created by guohy on 2022/10/19.
//  Copyright © 2022 ghy. All rights reserved.
//

#define kSystemFontName @"System.ttf"

#import "TLFontManager.h"
#import "CGFontToFontData.h"

@interface TLFontManager()

//外部字体
@property(nonatomic)NSString *injectionFontPath;

@end

@implementation TLFontManager

static TLFontManager *manager = nil;

+ (instancetype)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

+ (void)configSystemFont
{
    NSString *fontPath = [self systemFontPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:fontPath]) {
        
    } else {
        NSData *fontData = [CGFontToFontData fontDataForCGFont:CGFontCreateWithFontName((__bridge CFStringRef)@"PingFangSC-Regular")];
        [fontData writeToFile:fontPath atomically:YES];
    }
}

+ (NSString *)defaultFontPath
{
    NSString *fontPath = [[[self class] shared] injectionFontPath];
    if (!(fontPath.length) || ![[NSFileManager defaultManager] fileExistsAtPath:fontPath]) {
        fontPath = [self systemFontPath];
    }
    return fontPath;
}

+ (NSString *)systemFontPath
{
    NSString *fontPath = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%@", kSystemFontName]];
    return fontPath;
}

- (void)changeDefaultFont:(NSString *)fontPath
{
    self.injectionFontPath = fontPath;
}

@end
