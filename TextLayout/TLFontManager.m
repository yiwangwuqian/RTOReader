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

@implementation TLFontManager

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
    NSString *fontPath = [self systemFontPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:fontPath]) {
        fontPath = [[NSBundle mainBundle] pathForResource: @"站酷庆科黄油体" ofType: @"ttf"];
    }
    return fontPath;
}

+ (NSString *)systemFontPath
{
    NSString *fontPath = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%@", kSystemFontName]];
    return fontPath;
}

@end
