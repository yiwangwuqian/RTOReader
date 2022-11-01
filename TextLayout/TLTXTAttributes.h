//
//  TLTXTAttributes.h
//  TextLayout
//
//  Created by guohy on 2022/10/25.
//  Copyright © 2022 ghy. All rights reserved.
//

#ifndef TLTXTAttributes_h
#define TLTXTAttributes_h

#include <stdlib.h>
#include <stdbool.h>
#include "TLTXTTypes.h"

#ifdef __cplusplus

extern "C" {
#endif

typedef struct TLRange_ *TLRange;

typedef struct TLRangeArray_ *TLRangeArray;

typedef struct TLTXTAttributesArray_ *TLTXTAttributesArray;

struct TLRange_ {
    size_t location;
    size_t length;
};

typedef struct TLTXTAttributes_ {
    unsigned int fontSize;
    size_t fontStyle;
    size_t color;
    size_t lineSpacing;
    unsigned int firstHeadIndent;//大于0时数字指多少个字宽
    size_t paragraph;
    size_t placeholder;
} *TLTXTAttributes;

//------TLRangeArray即range数组

/// 创建数组对象
/// - Parameter array: 指针指向创建后的对象
void tl_range_array_create(TLRangeArray *array);

/// 数组增加元素
/// @param array 数组对象
/// @param range 元素
bool tl_range_array_add(TLRangeArray array,struct TLRange_ range);

/// 销毁对象
/// @param array 指针指向待销毁对象
void tl_range_array_destroy(TLRangeArray *array);

/// 获取元素数量
/// @param array 数组对象
size_t tl_range_array_get_count(TLRangeArray array);

/// 获取元素中的某一项
/// @param array 数组对象
/// @param index 索引
TLRange tl_range_array_object_at(TLRangeArray array,size_t index);

//------

void tl_range_get(TLRange range, size_t *location, size_t *length);

//------TLTXTAttributesArray即属性数组

/// 创建数组对象
/// - Parameter array: 指针指向创建后的对象
void tl_txt_attributes_array_create(TLTXTAttributesArray *array);

/// 数组增加元素
/// @param array 数组对象
/// @param attributes 元素
bool tl_txt_attributes_array_add(TLTXTAttributesArray array,struct TLTXTAttributes_ attributes);

/// 销毁对象
/// @param array 指针指向待销毁对象
void tl_txt_attributes_array_destroy(TLTXTAttributesArray *array);

/// 获取元素数量
/// @param array 数组对象
size_t tl_txt_attributes_array_get_count(TLTXTAttributesArray array);

/// 获取元素中的某一项
/// @param array 数组对象
/// @param index 索引
TLTXTAttributes tl_txt_attributes_array_object_at(TLTXTAttributesArray array,size_t index);

//------

#ifdef __cplusplus
}
#endif

#endif /* TLTXTAttributes_h */
