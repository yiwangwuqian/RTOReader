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

typedef struct RTOTXTWorker_* RTOTXTWorker;

void txt_worker_create(RTOTXTWorker *worker, char *text, int width, int height);

uint8_t *txt_worker_bitmap_next_page(RTOTXTWorker *worker);

uint8_t *txt_worker_bitmap_previous_page(RTOTXTWorker *worker);

#endif /* RTOTXTWorker_h */
