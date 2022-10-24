//
//  TLTXTCachePage.m
//  TextLayout
//
//  Created by guohy on 2022/10/24.
//  Copyright © 2022 ghy. All rights reserved.
//

#import "TLTXTCachePage.h"

@implementation TLTXTCachePage

- (void)dealloc
{
#ifdef DEBUG
    NSLog(@"%@ dealloc", self);
#endif
    if (_rowRectArray) {
        txt_row_rect_array_destroy(&_rowRectArray);
    }
}

@end
