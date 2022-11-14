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

size_t txt_row_rect_array_get_count(TLTXTRowRectArray array)
{
    return array->count;
}

TLTXTRectArray txt_row_rect_array_object_at(TLTXTRowRectArray array, int index)
{
    if (index < array->count) {
        return array->data[index];
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

void txt_worker_rect_array_from(TLTXTRowRectArray array, TLTXTRectArray *rect_array, int sx, int sy, int ex, int ey, size_t *s_index, size_t *e_index, size_t start_cursor)
{
    bool start_finded = false;
    bool end_finded = false;

    size_t index = start_cursor;
    
    for (size_t i=0; i<array->count; i++) {
        TLTXTRectArray *data = array->data;
        TLTXTRectArray row_array = data[i];
        for (size_t j=0; j<row_array->count; j++) {
            struct TLTXTRect_ one_rect = row_array->data[j];
            if (!start_finded) {
                if (sy >= one_rect.y && sy <= one_rect.yy) {
                    //开始和结束在同一行
                    if (ey >= one_rect.y && ey <= one_rect.yy) {
                        
                        //同一个字
                        if (sx >= one_rect.x && sx <= one_rect.xx && ex >= one_rect.x && ex <= one_rect.xx) {
                            start_finded = true;
                            end_finded = true;
                            
                            if (*rect_array == NULL) {
                                txt_rect_array_create(rect_array);
                            }
                            txt_rect_array_add(*rect_array, one_rect);
                            
                            *s_index = txt_row_rect_array_index_from(array, i, j);
                            *e_index = *s_index;
                            
                            //坐标匹配退出第二层for循环
                            break;
                        } else if (sx >= one_rect.x && sx <= one_rect.xx) {
                            start_finded = true;
                            
                            *s_index = txt_row_rect_array_index_from(array, i, j);
                            
                            if (*rect_array == NULL) {
                                txt_rect_array_create(rect_array);
                            }
                            
                            for (size_t k=j; k<row_array->count; k++) {
                                struct TLTXTRect_ k_one_rect = row_array->data[k];
                                if (ex >= k_one_rect.x && ex <= k_one_rect.xx) {
                                    end_finded = true;
                                    
                                    struct TLTXTRect_ result = {one_rect.x, one_rect.y, k_one_rect.xx, k_one_rect.yy};
                                    txt_rect_array_add(*rect_array, result);
                                    
                                    *e_index = txt_row_rect_array_index_from(array, i, k);
                                    break;
                                }
                            }
                            
                            //坐标匹配退出第二层for循环
                            break;
                        }
                        
                    } else {
                        if (sx >= one_rect.x && sx <= one_rect.xx) {
                            start_finded = true;
                            
                            struct TLTXTRect_ last_rect = row_array->data[row_array->count-1];
                            if (*rect_array == NULL) {
                                txt_rect_array_create(rect_array);
                            }
                            struct TLTXTRect_ result = {one_rect.x, one_rect.y, last_rect.xx, last_rect.yy};
                            txt_rect_array_add(*rect_array, result);
                            
                            *s_index = txt_row_rect_array_index_from(array, i, j);
                            
                            //坐标匹配退出第二层for循环
                            break;
                        }
                    }
                } else {
                    //退出第二层for循环 比较下一行
                    break;
                }
            } else if (!end_finded) {
                bool record_row = false;
                if (ey >= one_rect.y && ey <= one_rect.yy) {
                    if (ex >= one_rect.x && ex <= one_rect.xx) {
                        end_finded = true;
                        
                        struct TLTXTRect_ first_rect = row_array->data[0];
                        struct TLTXTRect_ result = {first_rect.x, first_rect.y, one_rect.xx, one_rect.yy};
                        txt_rect_array_add(*rect_array, result);
                        
                        *e_index = txt_row_rect_array_index_from(array, i, j);
                        
                        //坐标匹配退出第二层for循环
                        break;
                    } else if (j == row_array->count-1) {
                        end_finded = true;
                        //结束点没有落进最后一个文字的区域 也需要记录整行
                        record_row = true;
                    }
                } else {
                    record_row = true;
                }
                
                if (record_row) {
                    //记录这一行
                    struct TLTXTRect_ first_rect = row_array->data[0];
                    struct TLTXTRect_ last_rect = row_array->data[row_array->count-1];
                    struct TLTXTRect_ result = {first_rect.x, first_rect.y, last_rect.xx, last_rect.yy};
                    txt_rect_array_add(*rect_array, result);
                    
                    if (end_finded) {
                        *e_index = txt_row_rect_array_index_from(array, i, row_array->count-1);
                    }
                    
                    //退出第二层for循环 比较下一行
                    break;
                }
            }
        }
        
        //不需要再循环了
        if (start_finded && end_finded) {
            break;
        }
    }
    
    *s_index += index;
    *e_index += index;
}

void txt_paging_rect_array_create(TLTXTPagingRectArray *array)
{
    TLTXTPagingRectArray object = calloc(1, sizeof(struct TLTXTPagingRectArray_));
    
    size_t length = 20;
    object->length = length;
    object->data = calloc(length, sizeof(TLTXTRowRectArray));
    
    *array = object;
}

bool txt_paging_rect_array_add(struct TLTXTPagingRectArray_ *array,TLTXTRowRectArray item)
{
    if( !((*array).count < (*array).length) ) {
        size_t length = (*array).length + 100;
        TLTXTRowRectArray *data = realloc((*array).data, length*sizeof(TLTXTRowRectArray));
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

void txt_paging_rect_array_destroy(TLTXTPagingRectArray *array)
{
    if ((*array)->count > 0) {
        for (size_t i = 0; i< (*array)->count; i++) {
            txt_row_rect_array_destroy((*array)->data+i);
        }
    }
    free((*array)->data);
    
    free(*array);
    *array = NULL;
}

size_t txt_paging_rect_array_get_count(TLTXTPagingRectArray array)
{
    return array->count;
}

TLTXTRowRectArray txt_paging_rect_array_object_at(TLTXTPagingRectArray array, size_t index)
{
    return array->data[index];
}
