//
//  TLTXTPageHelper.m
//  TextLayout
//
//  Created by guohy on 2022/10/28.
//  Copyright © 2022 ghy. All rights reserved.
//

#import "TLTXTPageHelper.h"
#import "TLAttributedString.h"
#include "TLTXTWorker.h"

@interface TLTXTPageHelper()
@property(nonatomic)TLAttributedString  *attributedString;
@property(nonatomic)CGSize              pageSize;
@property(nonatomic)TLTXTWorker         worker;
@end

@implementation TLTXTPageHelper

- (void)dealloc
{
#ifdef DEBUG
    NSLog(@"%@ dealloc", self);
#endif
    txt_worker_destroy(&_worker);
}

#pragma mark- Public methods

+ (void)checkRangeAttributes:(TLAttributedString *)aString range:(TLRange)range rArray:(TLRangeArray *)rArray aArray:(TLTXTAttributesArray *)aArray
{
    NSArray *subRanges = nil;
    NSArray<NSDictionary *> *attributes =
    [aString attributesCheckRange:NSMakeRange(range->location, range->length) haveSubRanges:&subRanges];
    if (subRanges != nil && attributes != nil) {
        tl_range_array_create(rArray);
        tl_txt_attributes_array_create(aArray);
        
        for (NSInteger i=0; i<subRanges.count; i++) {
            NSValue *rValue = subRanges[i];
            NSRange oneRange = [rValue rangeValue];
            struct TLRange_ tlRange = {oneRange.location,oneRange.length};
            tl_range_array_add(*rArray, tlRange);
            
            NSDictionary *oneAttributeDict = attributes[i];
            struct TLTXTAttributes_ tlAttributes = {0,0,0,0,0,0,0,0};
            for (NSNumber *typeNumber in oneAttributeDict.allKeys) {
                NSInteger result = [oneAttributeDict[typeNumber] integerValue];
                TLTXTAttributesNameType oneType = (TLTXTAttributesNameType)[typeNumber integerValue];
                switch (oneType) {
                    case TLTXTAttributesNameTypeFontSize:
                        tlAttributes.fontSize = (unsigned int)result;
                        break;
                    case TLTXTAttributesNameTypeFontStyle:
                        tlAttributes.fontStyle = result;
                        break;
                    case TLTXTAttributesNameTypeColor:
                        tlAttributes.color = result;
                        break;
                    case TLTXTAttributesNameTypeParagraphFirstHeadIndent:
                        tlAttributes.firstHeadIndent = (unsigned int)result;
                        break;
                    case TLTXTAttributesNameTypeParagraphSpacing:
                        tlAttributes.paragraphSpacing = (unsigned int)result;
                        break;
                        /*
                    case TLTXTAttributesNameTypeParagraph:
                        tlAttributes.paragraph = result;
                        break;
                    case TLTXTAttributesNameTypePlaceholder:
                        tlAttributes.placeholder = result;
                        break;
                         */
                    default:
                        break;
                }
            }
            tl_txt_attributes_array_add(*aArray, tlAttributes);
        }
    }
}

+ (TLTXTAttributes)checkDefaultAttributes:(TLAttributedString *)aString
{
    NSDictionary *attributes =
    [aString defaultAttributes];
    if (attributes.count) {
        TLTXTAttributes oneAttributes = calloc(1, sizeof(struct TLTXTAttributes_));
        for (NSNumber *typeNumber in attributes.allKeys) {
            NSInteger result = [attributes[typeNumber] integerValue];
            TLTXTAttributesNameType oneType = (TLTXTAttributesNameType)[typeNumber integerValue];
            switch (oneType) {
                case TLTXTAttributesNameTypeFontSize:
                    oneAttributes->fontSize = (unsigned int)result;
                    break;
                case TLTXTAttributesNameTypeColor:
                    oneAttributes->color = result;
                    break;
                case TLTXTAttributesNameTypeColorMode:
                    oneAttributes->colorMode = (unsigned int)result;
                    break;
                case TLTXTAttributesNameTypeLineSpacing:
                    oneAttributes->lineSpacing = result;
                    break;
                case TLTXTAttributesNameTypeParagraphFirstHeadIndent:
                    oneAttributes->firstHeadIndent = (unsigned int)result;
                    break;
                case TLTXTAttributesNameTypeParagraphSpacing:
                    oneAttributes->paragraphSpacing = (unsigned int)result;
                    break;
                default:
                    break;
            }
        }
        return oneAttributes;
    }
    return NULL;
}

@end
