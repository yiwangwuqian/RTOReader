//
//  TLTXTWorker.h
//  RTOReader
//
//  Created by ghy on 2021/6/15.
//  Copyright © 2021 ghy. All rights reserved.
//

#ifndef TLTXTWorker_h
#define TLTXTWorker_h

#include <stdlib.h>
#include <stdbool.h>
#include "TLTXTRowRect.h"
#include "TLTXTAttributes.h"

#ifdef __cplusplus

extern "C" {
#endif

typedef struct TLTXTWorker_* TLTXTWorker;

//根据页范围获取属性
typedef void (*TLTXTWorker_RangeAttributesFunc)(TLTXTWorker worker,
                                                TLRange range,
                                                TLRangeArray *rArray,
                                                TLTXTAttributesArray *aArray);

//获取默认属性 调用者需要负责返回结果的销毁
typedef TLTXTAttributes (*TLTXTWorker_DefaultAttributesFunc)(TLTXTWorker worker);

void txt_worker_create(TLTXTWorker *worker, const char *text, int width, int height);

void txt_worker_set_range_attributes_callback(TLTXTWorker worker, TLTXTWorker_RangeAttributesFunc func);

void txt_worker_set_default_attributes_callback(TLTXTWorker worker, TLTXTWorker_DefaultAttributesFunc func);

void txt_worker_set_context(TLTXTWorker worker, void *context);

void *txt_worker_get_context(TLTXTWorker worker);

/// 销毁TLTXTWorker
/// - Parameter worker: worker对象
void txt_worker_destroy(TLTXTWorker *worker);

/// TLTXTWorker数据分页操作
/// - Parameter worker: worker对象
void txt_worker_data_paging(TLTXTWorker *worker);

/// TLTXTWorker总页数
/// - Parameter worker: worker对象
size_t txt_worker_total_page(TLTXTWorker *worker);

///  TLTXTWorker绘制一页
/// - Parameters:
///   - worker: worker对象
///   - page: 页码
uint8_t *txt_worker_bitmap_one_page(TLTXTWorker *worker, size_t page,TLTXTRowRectArray *page_row_rect_array);

uint32_t* txt_worker_codepoint_in_range(TLTXTWorker *worker, size_t start, size_t end, size_t *count);

uint32_t txt_worker_codepoint_at(TLTXTWorker *worker,int x,int y,TLTXTRect* contains);

size_t txt_worker_page_cursor_array_get(TLTXTWorker worker,size_t page);

#ifdef __cplusplus
}
#endif

#endif /* TLTXTWorker_h */
