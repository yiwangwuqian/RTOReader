//
//  TLFontManager.h
//  RTOReader
//
//  Created by guohy on 2022/10/19.
//  Copyright © 2022 ghy. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TLFontManager : NSObject

+ (void)configSystemFont;

+ (NSString *)defaultFontPath;

+ (NSString *)systemFontPath;

@end

NS_ASSUME_NONNULL_END
