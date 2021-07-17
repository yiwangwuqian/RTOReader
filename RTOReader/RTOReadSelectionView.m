//
//  RTOReadSelectionView.m
//  RTOReader
//
//  Created by ghy on 2021/7/14.
//  Copyright © 2021 ghy. All rights reserved.
//

#import "RTOReadSelectionView.h"

@implementation RTOReadSelectionView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)setRectArray:(NSArray *)rectArray
{
    _rectArray = rectArray;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextClearRect(context, self.bounds);
    
    CGContextSetFillColorWithColor(context, [UIColor colorWithRed:0 green:0 blue:1.0 alpha:0.4].CGColor);

    if (self.rectArray.count) {
        for (NSValue *rectValue in self.rectArray) {
            CGContextMoveToPoint(context, [rectValue CGRectValue].origin.x, [rectValue CGRectValue].origin.y);
            CGContextAddRect(context, [rectValue CGRectValue]);
        }
    }
    CGContextFillPath(context);
    
    CGContextDrawPath(context, kCGPathStroke);
}

@end
