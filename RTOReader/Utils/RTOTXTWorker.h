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

typedef struct RTOTXTWorker_* RTOTXTWorker;

void txt_worker_create(RTOTXTWorker *worker, char *text, int width, int height);

uint8_t *txt_worker_bitmap_next_page(RTOTXTWorker *worker);

uint8_t *txt_worker_bitmap_previous_page(RTOTXTWorker *worker);

typedef struct RTOTXTRect_* RTOTXTRect;

void txt_rect_values(RTOTXTRect* rect, int *x, int *y, int *xx, int *yy);

uint32_t txt_worker_codepoint_at(RTOTXTWorker *worker,int x,int y,RTOTXTRect* contains);

#endif /* RTOTXTWorker_h */
