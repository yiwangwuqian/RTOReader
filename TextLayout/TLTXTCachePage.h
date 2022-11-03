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
@property(nonatomic)NSString            *backupPath;
@property(nonatomic)uint8_t             *backupBytes;
@property(nonatomic)TLTXTRowRectArray   rowRectArray;
@property(nonatomic)NSInteger           beforeCursor;//上一页游标(-1时为第一页)
@property(nonatomic)NSInteger           cursor;//游标

- (void)saveBackup;//保存备份

- (void)restoreBackup;//恢复备份
@end

NS_ASSUME_NONNULL_END
