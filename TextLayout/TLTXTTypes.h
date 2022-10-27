//
//  TLTXTTypes.h
//  RTOReader
//
//  Created by guohy on 2022/10/24.
//  Copyright © 2022 ghy. All rights reserved.
//

#ifndef TLTXTTypes_h
#define TLTXTTypes_h

/**
 *排版需要数据信息类型
 */
typedef enum TLTXTAttributesNameType{
    TLTXTAttributesNameTypeNone = 0,
    TLTXTAttributesNameTypeFontSize,    //字号
    TLTXTAttributesNameTypeFontStyle,   //字体样式  暂无实现
    TLTXTAttributesNameTypeColor,       //文字颜色
    TLTXTAttributesNameTypeLineSpacing, //行间距
    TLTXTAttributesNameTypeParagraph,   //段落
    TLTXTAttributesNameTypePlaceholder, //占位    暂无实现
} TLTXTAttributesNameType;

#endif /* TLTXTTypes_h */
