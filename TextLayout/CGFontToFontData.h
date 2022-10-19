//
//  CGFontToFontData.h
//  RTOReader
//
//  Created by guohy on 2022/10/19.
//  Copyright © 2022 ghy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

//将字体转成可写入文件的数据
@interface CGFontToFontData : NSObject
+ (NSData *)fontDataForCGFont:(CGFontRef)cgFont;
@end

NS_ASSUME_NONNULL_END
