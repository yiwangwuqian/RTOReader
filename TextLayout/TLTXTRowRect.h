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

#ifdef __cplusplus

extern "C" {
#endif
typedef struct TLTXTRect_* TLTXTRect;
typedef struct TLTXTRectArray_* TLTXTRectArray;
typedef struct TLTXTRowRectArray_* TLTXTRowRectArray;
typedef struct TLTXTPagingRectArray_* TLTXTPagingRectArray;

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
    /**
     *纯文本的排版，\n有可能占用一行也有可能不占用任何空间
     *所以一页的TLTXTRect_数量和文字数量是对不上的
     *这个字段新增的 使用到的地方需要看是否漏掉
     */
    int32_t codepoint_index;
};

struct TLTXTRowRectArray_ {
    TLTXTRectArray *data;
    size_t length;//真实长度
    size_t count;//元素个数
};

void txt_rect_array_create(TLTXTRectArray *array);

bool txt_rect_array_add(struct TLTXTRectArray_ *array,struct TLTXTRect_ rect);

/// 移除最后一个元素
/// @param array 数组对象
void txt_rect_array_remove_last(struct TLTXTRectArray_ *array);

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

size_t txt_row_rect_array_get_count(TLTXTRowRectArray array);

TLTXTRectArray txt_row_rect_array_object_at(TLTXTRowRectArray array, int index);

size_t txt_row_rect_array_index_from(TLTXTRowRectArray array, size_t r_index, size_t c_index);

bool txt_row_rect_array_add(struct TLTXTRowRectArray_ *array,TLTXTRectArray item);

void txt_row_rect_array_destroy(TLTXTRowRectArray *array);

void txt_rect_values(TLTXTRect* rect, int *x, int *y, int *xx, int *yy);

/// 用开始点和结束点 获取TLTXTRectArray对象
/// @param array  TLTXTRowRectArray对象
/// @param rect_array 结果
/// @param sx 开始x
/// @param sy 开始y
/// @param ex 结束x
/// @param ey 结束y
void txt_worker_rect_array_from(TLTXTRowRectArray array, TLTXTRectArray *rect_array, int sx, int sy, int ex, int ey, size_t *s_index, size_t *e_index, size_t start_cursor);

/// 分页使用
struct TLTXTPagingRectArray_ {
    TLTXTRowRectArray *data;//每个元素代表一页对应的数据
    size_t length;//真实长度
    size_t count;//元素个数
};

void txt_paging_rect_array_create(TLTXTPagingRectArray *array);

bool txt_paging_rect_array_add(struct TLTXTPagingRectArray_ *array,TLTXTRowRectArray item);

void txt_paging_rect_array_destroy(TLTXTPagingRectArray *array);

size_t txt_paging_rect_array_get_count(TLTXTPagingRectArray array);

TLTXTRowRectArray txt_paging_rect_array_object_at(TLTXTPagingRectArray array, size_t index);
#ifdef __cplusplus
}
#endif

#endif /* RTOTXTRowRect_h */
