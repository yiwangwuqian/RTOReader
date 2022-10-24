//
//  TLTXTCachePage.h
//  TextLayout
//
//  Created by guohy on 2022/10/24.
//  Copyright © 2022 ghy. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "TLTXTRowRect.h"

NS_ASSUME_NONNULL_BEGIN

@interface TLTXTCachePage : NSObject

@property(nonatomic)NSInteger           pageNum;
@property(nonatomic)UIImage             *image;
@property(nonatomic)TLTXTRowRectArray   rowRectArray;
@property(nonatomic)NSInteger           beforeCursor;//上一页游标(-1时为第一页)
@property(nonatomic)NSInteger           cursor;//游标

@end

NS_ASSUME_NONNULL_END
