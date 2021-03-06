//
//  RTOTXTWorker.h
//  RTOReader
//
//  Created by ghy on 2021/6/15.
//  Copyright © 2021 ghy. All rights reserved.
//

#ifndef RTOTXTWorker_h
#define RTOTXTWorker_h

#include <stdlib.h>
#include <stdbool.h>

#ifdef __cplusplus

extern "C" {
#endif

typedef struct RTOTXTWorker_* RTOTXTWorker;

void txt_worker_create(RTOTXTWorker *worker, char *text, int width, int height);

uint8_t *txt_worker_bitmap_next_page(RTOTXTWorker *worker);

uint8_t *txt_worker_bitmap_previous_page(RTOTXTWorker *worker);

typedef struct RTOTXTRect_* RTOTXTRect;

void txt_rect_values(RTOTXTRect* rect, int *x, int *y, int *xx, int *yy);

uint32_t* txt_worker_codepoint_in_range(RTOTXTWorker *worker, size_t start, size_t end, size_t *count);

uint32_t txt_worker_codepoint_at(RTOTXTWorker *worker,int x,int y,RTOTXTRect* contains);

typedef struct RTOTXTRectArray_* RTOTXTRectArray;

/// 用开始点和结束点 获取RTOTXTRectArray对象
/// @param worker  worker对象
/// @param rect_array 结果
/// @param sx 开始x
/// @param sy 开始y
/// @param ex 结束x
/// @param ey 结束y
void txt_worker_rect_array_from(RTOTXTWorker *worker, RTOTXTRectArray *rect_array, int sx, int sy, int ex, int ey, size_t *s_index, size_t *e_index);

/// 获取元素数量
/// @param rect_array 数组对象
size_t txt_worker_rect_array_get_count(RTOTXTRectArray *rect_array);

/// 获取指定元素
/// @param rect_array 数组对象
/// @param index 索引
RTOTXTRect txt_worker_rect_array_object_at(RTOTXTRectArray *rect_array, int index);

/// 销毁对象
/// @param array 待销毁对象
void txt_rect_array_destroy(RTOTXTRectArray *array);

#ifdef __cplusplus
}
#endif

#endif /* RTOTXTWorker_h */
