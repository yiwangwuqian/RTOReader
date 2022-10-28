//
//  TLTXTAttributes.c
//  TextLayout
//
//  Created by guohy on 2022/10/25.
//  Copyright © 2022 ghy. All rights reserved.
//

#include "TLTXTAttributes.h"

struct TLRangeArray_ {
    TLRange data;
    size_t length;//真实长度
    size_t count;//元素个数
};

struct TLTXTAttributesArray_ {
    TLTXTAttributes data;
    size_t length;//真实长度
    size_t count;//元素个数
};

void tl_range_array_create(TLRangeArray *array)
{
    TLRangeArray object = calloc(1, sizeof(struct TLRangeArray_));
    
    size_t length = 100;
    object->length = length;
    object->data = calloc(length, sizeof(struct TLRange_));
    
    *array = object;
}

bool tl_range_array_add(TLRangeArray array,struct TLRange_ range)
{
    if( !((*array).count < (*array).length) ) {
        size_t length = (*array).length + 100;
        struct TLRange_ *data = realloc((*array).data, length*sizeof(struct TLRange_));
        if (data == NULL) {
            return false;
        }
        (*array).data = data;
        (*array).length = length;
    }
    (*array).data[(*array).count] = range;
    (*array).count+=1;
    return true;
}

void tl_range_array_destroy(TLRangeArray *array)
{
    free((*array)->data);
    free(*array);
    *array = NULL;
}

size_t tl_range_array_get_count(TLRangeArray array)
{
    return array->count;
}

TLRange tl_range_array_object_at(TLRangeArray array,size_t index)
{
    return array->data+index;
}

void tl_range_get(TLRange range, size_t *location, size_t *length)
{
    if (range != NULL) {
        *location = range->location;
        *length = range->length;
    }
}

void tl_txt_attributes_array_create(TLTXTAttributesArray *array)
{
    TLTXTAttributesArray object = calloc(1, sizeof(struct TLTXTAttributesArray_));
    
    size_t length = 100;
    object->length = length;
    object->data = calloc(length, sizeof(struct TLTXTAttributes_));
    
    *array = object;
}

bool tl_txt_attributes_array_add(TLTXTAttributesArray array,struct TLTXTAttributes_ attributes)
{
    if( !((*array).count < (*array).length) ) {
        size_t length = (*array).length + 100;
        struct TLTXTAttributes_ *data = realloc((*array).data, length*sizeof(struct TLTXTAttributes_));
        if (data == NULL) {
            return false;
        }
        (*array).data = data;
        (*array).length = length;
    }
    (*array).data[(*array).count] = attributes;
    (*array).count+=1;
    return true;
}

void tl_txt_attributes_array_destroy(TLTXTAttributesArray *array)
{
    free((*array)->data);
    free(*array);
    *array = NULL;
}

size_t tl_txt_attributes_array_get_count(TLTXTAttributesArray array)
{
    return array->count;
}

TLTXTAttributes tl_txt_attributes_array_object_at(TLTXTAttributesArray array,size_t index)
{
    return array->data+index;
}
