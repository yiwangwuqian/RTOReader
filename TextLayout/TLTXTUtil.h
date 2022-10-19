//
//  TLTXTUtil.h
//  RTOReader
//
//  Created by ghy on 2021/10/30.
//  Copyright © 2021 ghy. All rights reserved.
//

#ifndef TLTXTUtil_h
#define TLTXTUtil_h

#include <stddef.h>

#ifdef __cplusplus

extern "C" {
#endif

void txt_file_content(const char *path, char** content,size_t *content_len);

#ifdef __cplusplus
}
#endif

#endif /* TLTXTUtil_h */
