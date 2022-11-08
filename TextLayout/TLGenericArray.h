//
//  TLGenericArray.h
//  TextLayout
//
//  Created by guohy on 2022/11/8.
//  Copyright © 2022 ghy. All rights reserved.
//

#ifndef TLGenericArray_h
#define TLGenericArray_h

#include <stdlib.h>
#include <stdbool.h>

#ifdef __cplusplus

extern "C" {
#endif

typedef struct TLGenericArray_ *TLGenericArray;

struct TLGenericArray_ {
    size_t *data;
    size_t length;//真实长度
    size_t count;//元素个数
};

/// 创建数组对象
/// - Parameter array: 数组对象
void tl_generic_array_create(TLGenericArray *array);

/// 数组增加元素
/// @param array 数组对象
/// @param item  新元素
bool tl_generic_array_add(struct TLGenericArray_ *array,size_t item);

/// 销毁对象
/// @param array 待销毁对象
void tl_generic_array_destroy(TLGenericArray *array);

/// 获取元素数量
/// @param array 数组对象
size_t tl_generic_array_get_count(TLGenericArray array);

/// 获取指定元素
/// @param array 数组对象
/// @param index 索引
size_t tl_generic_array_object_at(TLGenericArray array, int index);

#ifdef __cplusplus
}
#endif

#endif /* TLGenericArray_h */
