//
//  TLGenericArray.c
//  TextLayout
//
//  Created by guohy on 2022/11/8.
//  Copyright © 2022 ghy. All rights reserved.
//

#include "TLGenericArray.h"

void tl_generic_array_create(TLGenericArray *array)
{
    TLGenericArray object = calloc(1, sizeof(struct TLGenericArray_));
    
    size_t length = 10;
    object->length = length;
    object->data = calloc(length, sizeof(size_t));
    
    *array = object;
}

bool tl_generic_array_add(struct TLGenericArray_ *array,size_t item)
{
    if( !((*array).count < (*array).length) ) {
        size_t length = (*array).length + 10;
        size_t *data = realloc((*array).data, length*sizeof(size_t));
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

void tl_generic_array_destroy(TLGenericArray *array)
{
    free((*array)->data);
    free(*array);
    *array = NULL;
}

size_t tl_generic_array_get_count(TLGenericArray array)
{
    return array->count;
}

size_t tl_generic_array_object_at(TLGenericArray array, int index)
{
    return array->data[index];
}
