//
//  RTOTXTRowRect.c
//  TextLayout
//
//  Created by guohy on 2022/10/24.
//  Copyright © 2022 ghy. All rights reserved.
//

#include "TLTXTRowRect.h"

//------TLTXTRectArray_ 数组只有创建、新增元素、销毁操作

void txt_rect_array_create(TLTXTRectArray *array)
{
    TLTXTRectArray object = calloc(1, sizeof(struct TLTXTRectArray_));
    
    size_t length = 100;
    object->length = length;
    object->data = calloc(length, sizeof(struct TLTXTRect_));
    
    *array = object;
}

bool txt_rect_array_add(struct TLTXTRectArray_ *array,struct TLTXTRect_ rect)
{
    if( !((*array).count < (*array).length) ) {
        size_t length = (*array).length + 100;
        struct TLTXTRect_ *data = realloc((*array).data, length*sizeof(struct TLTXTRect_));
        if (data == NULL) {
            return false;
        }
        (*array).data = data;
        (*array).length = length;
    }
    (*array).data[(*array).count] = rect;
    (*array).count+=1;
    return true;
}

void txt_rect_array_destroy(TLTXTRectArray *array)
{
    free((*array)->data);
    free(*array);
    *array = NULL;
}

size_t txt_worker_rect_array_get_count(TLTXTRectArray *rect_array)
{
    return (*rect_array)->count;
}

TLTXTRect txt_worker_rect_array_object_at(TLTXTRectArray *rect_array, int index)
{
    return &(*rect_array)->data[index];
}

//------

//------TLTXTRowRectArray 数组只有创建、新增元素、销毁操作

void txt_row_rect_array_create(TLTXTRowRectArray *array)
{
    TLTXTRowRectArray object = calloc(1, sizeof(struct TLTXTRowRectArray_));
    
    size_t length = 20;
    object->length = length;
    object->data = calloc(length, sizeof(TLTXTRectArray));
    
    *array = object;
}

TLTXTRectArray txt_row_rect_array_current(TLTXTRowRectArray array)
{
    if (array->count) {
        return array->data[array->count-1];
    }
    return NULL;
}

size_t txt_row_rect_array_index_from(TLTXTRowRectArray array, size_t r_index, size_t c_index)
{
    size_t result=0;
    for (size_t i=0; i<array->count; i++) {
        TLTXTRectArray *data = array->data;
        TLTXTRectArray row_array = data[i];
        if (r_index == i) {
            for (size_t j=0; j<row_array->count; j++) {
                if (c_index == j) {
                    result += j;
                    break;
                }
            }
            break;
        }
        result += row_array->count;
    }
    return result;
}

bool txt_row_rect_array_add(struct TLTXTRowRectArray_ *array,TLTXTRectArray item)
{
    if( !((*array).count < (*array).length) ) {
        size_t length = (*array).length + 20;
        TLTXTRectArray *data = realloc((*array).data, length*sizeof(struct TLTXTRectArray_));
        if (data == NULL) {
            return false;
        }
        (*array).data = data;
        (*array).length = length;
    }
    (*array).data[(*array).count] = item;
    (*array).count+=1;
    return true;
}

void txt_row_rect_array_destroy(TLTXTRowRectArray *array)
{
    if ((*array)->count > 0) {
        for (size_t i = 0; i< (*array)->count; i++) {
            TLTXTRectArray oneElem = (*array)->data[i];
            txt_rect_array_destroy(&oneElem);
        }
    }
    free((*array)->data);
    
    free(*array);
    *array = NULL;
}

//------

void txt_rect_values(TLTXTRect* rect, int *x, int *y, int *xx, int *yy)
{
    if (rect != NULL) {
        *x = (*rect)->x;
        *y = (*rect)->y;
        *xx = (*rect)->xx;
        *yy = (*rect)->yy;
    }
}
