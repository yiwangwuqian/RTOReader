//
//  RTOTXTRowRect.h
//  TextLayout
//
//  Created by guohy on 2022/10/24.
//  Copyright © 2022 ghy. All rights reserved.
//

#ifndef RTOTXTRowRect_h
#define RTOTXTRowRect_h

#include <stdlib.h>
#include <stdbool.h>

typedef struct TLTXTRect_* TLTXTRect;
typedef struct TLTXTRectArray_* TLTXTRectArray;
typedef struct TLTXTRowRectArray_* TLTXTRowRectArray;

struct TLTXTRectArray_ {
    struct TLTXTRect_ *data;
    size_t length;//真实长度
    size_t count;//元素个数
};

struct TLTXTRect_ {
    int32_t x;
    int32_t y;
    int32_t xx;//x最大值
    int32_t yy;//y最大值
};

struct TLTXTRowRectArray_ {
    TLTXTRectArray *data;
    size_t length;//真实长度
    size_t count;//元素个数
};

void txt_rect_array_create(TLTXTRectArray *array);

bool txt_rect_array_add(struct TLTXTRectArray_ *array,struct TLTXTRect_ rect);

/// 销毁对象
/// @param array 待销毁对象
void txt_rect_array_destroy(TLTXTRectArray *array);

/// 获取元素数量
/// @param rect_array 数组对象
size_t txt_worker_rect_array_get_count(TLTXTRectArray *rect_array);

/// 获取指定元素
/// @param rect_array 数组对象
/// @param index 索引
TLTXTRect txt_worker_rect_array_object_at(TLTXTRectArray *rect_array, int index);

void txt_row_rect_array_create(TLTXTRowRectArray *array);

TLTXTRectArray txt_row_rect_array_current(TLTXTRowRectArray array);

size_t txt_row_rect_array_index_from(TLTXTRowRectArray array, size_t r_index, size_t c_index);

bool txt_row_rect_array_add(struct TLTXTRowRectArray_ *array,TLTXTRectArray item);

void txt_row_rect_array_destroy(TLTXTRowRectArray *array);

void txt_rect_values(TLTXTRect* rect, int *x, int *y, int *xx, int *yy);

#endif /* RTOTXTRowRect_h */
