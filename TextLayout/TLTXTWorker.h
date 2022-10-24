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

#ifdef __cplusplus

extern "C" {
#endif

typedef struct TLTXTWorker_* TLTXTWorker;

void txt_worker_create(TLTXTWorker *worker, char *text, int width, int height);

/// TLTXTWorker是否可以向后翻页
/// - Parameter worker: worker对象
bool txt_worker_next_able(TLTXTWorker *worker);

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
