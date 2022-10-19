//
//  RTOTXTWorker.c
//  RTOReader
//
//  Created by ghy on 2021/6/15.
//  Copyright © 2021 ghy. All rights reserved.
//

#include "RTOTXTWorker.h"
#include "FileWrapper.h"

#include <ft2build.h>
#include FT_FREETYPE_H

#include "hb-ft.h"

typedef struct RTOTXTRowRectArray_* RTOTXTRowRectArray;

struct RTOTXTWorker_ {
    char *content;
    size_t utf8_length;
    
    size_t cursor;
    
    int width;
    int height;
    
    FT_Library    *library;
    FT_Face       face;
    hb_buffer_t   *buf;
    hb_codepoint_t *codepoints;
    RTOTXTRowRectArray array;
    
    size_t current_page;
    size_t page_cursors[100];//这里还需要修改 页数过多时会有问题
};

//------RTOTXTRectArray_ 数组只有创建、新增元素、销毁操作

struct RTOTXTRectArray_ {
    struct RTOTXTRect_ *data;
    size_t length;//真实长度
    size_t count;//元素个数
};

struct RTOTXTRect_ {
    int32_t x;
    int32_t y;
    int32_t xx;//x最大值
    int32_t yy;//y最大值
};

void txt_rect_array_create(RTOTXTRectArray *array)
{
    RTOTXTRectArray object = calloc(1, sizeof(struct RTOTXTRectArray_));
    
    size_t length = 100;
    object->length = length;
    object->data = calloc(length, sizeof(struct RTOTXTRect_));
    
    *array = object;
}

bool txt_rect_array_add(struct RTOTXTRectArray_ *array,struct RTOTXTRect_ rect)
{
    if( !((*array).count < (*array).length) ) {
        size_t length = (*array).length + 100;
        struct RTOTXTRect_ *data = realloc((*array).data, length*sizeof(struct RTOTXTRect_));
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

void txt_rect_array_destroy(RTOTXTRectArray *array)
{
    free((*array)->data);
    free(*array);
}

//------

//------RTOTXTRowRectArray_ 数组只有创建、新增元素、销毁操作

struct RTOTXTRowRectArray_ {
    RTOTXTRectArray *data;
    size_t length;//真实长度
    size_t count;//元素个数
};

void txt_row_rect_array_create(RTOTXTRowRectArray *array)
{
    RTOTXTRowRectArray object = calloc(1, sizeof(struct RTOTXTRowRectArray_));
    
    size_t length = 20;
    object->length = length;
    object->data = calloc(length, sizeof(RTOTXTRectArray));
    
    *array = object;
}

RTOTXTRectArray txt_row_rect_array_current(RTOTXTRowRectArray array)
{
    if (array->count) {
        return array->data[array->count-1];
    }
    return NULL;
}

size_t txt_row_rect_array_index_from(RTOTXTRowRectArray array, size_t r_index, size_t c_index)
{
    size_t result=0;
    for (size_t i=0; i<array->count; i++) {
        RTOTXTRectArray *data = array->data;
        RTOTXTRectArray row_array = data[i];
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

bool txt_row_rect_array_add(struct RTOTXTRowRectArray_ *array,RTOTXTRectArray item)
{
    if( !((*array).count < (*array).length) ) {
        size_t length = (*array).length + 20;
        RTOTXTRectArray *data = realloc((*array).data, length*sizeof(struct RTOTXTRectArray_));
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

void txt_row_rect_array_destroy(RTOTXTRowRectArray *array)
{
    txt_rect_array_destroy((*array)->data);
    free((*array)->data);
    
    free(*array);
    *array = NULL;
}

//------

bool txt_worker_previous_able(RTOTXTWorker *worker)
{
    return false;
}

bool txt_worker_next_able(RTOTXTWorker *worker)
{
    if ((*worker)->utf8_length == (*worker)->cursor) {
        return false;
    }
    
    return true;
}

void txt_worker_create(RTOTXTWorker *worker, char *text, int width, int height)
{
    FT_Library    library;
    FT_Face       face;
    
    FT_Error      error;
    
    error = FT_Init_FreeType( &library );
    const char *fontPath = GetDefaultFontPath();
    if (!error) {
        hb_buffer_t *buf;
        buf = hb_buffer_create();
        hb_buffer_add_utf8(buf, text, -1, 0, -1);
        
        hb_buffer_set_direction(buf, HB_DIRECTION_LTR);
        hb_buffer_set_script(buf, HB_SCRIPT_HAN);
        hb_buffer_set_language(buf, hb_language_from_string("ch", -1));
        
        error = FT_New_Face( library, fontPath, 0, &face );/* create face object */
        if (!error) {
            
            RTOTXTWorker object = calloc(1, sizeof(struct RTOTXTWorker_));
            object->library = &library;
            object->face = face;
            
            object->buf = buf;
            object->utf8_length = hb_buffer_get_length(buf);
            
            unsigned int glyph_count;
            hb_glyph_info_t *glyph_info = hb_buffer_get_glyph_infos(buf, &glyph_count);
            hb_codepoint_t *codepoints = calloc(glyph_count, sizeof(hb_codepoint_t));
            for (unsigned int i=0; i<glyph_count; i++) {
                codepoints[i] = glyph_info[i].codepoint;
            }
            object->codepoints = codepoints;
            
            hb_font_t *font = hb_ft_font_create_referenced(face);
            hb_shape(font, buf, NULL, 0);
            
            object->width = width;
            object->height = height;
            
            object->current_page = -1;
            
            *worker = object;
        } else {
            hb_buffer_destroy(buf);
            
            FT_Done_Face    (face);
            FT_Done_FreeType(library);
        }
    } else {
        FT_Done_FreeType(library);
    }
}

uint8_t *txt_worker_bitmap_one_page(RTOTXTWorker *worker, size_t page)
{
    if (!txt_worker_next_able(worker)) {
        return NULL;
    }
    
    FT_Face       face = (*worker)->face;
    
    FT_GlyphSlot  slot;
    FT_Error      error;
    
    hb_buffer_t *buf = (*worker)->buf;
    
    unsigned int screenDpi = GetScreenDpi();
    
    /* use 50pt at 100dpi */
    error = FT_Set_Char_Size( face,
                             40/1136.0*screenDpi * 64,
                             0,
                             screenDpi,
                             0 );                /* set character size */
    
    unsigned int glyph_count;
    hb_glyph_info_t *glyph_info = hb_buffer_get_glyph_infos(buf, &glyph_count);
    hb_glyph_position_t *glyph_pos = hb_buffer_get_glyph_positions(buf, &glyph_count);
    
    unsigned int totalWidth=0;
    unsigned int totalHeight=0;
    totalWidth = (*worker)->width;
    totalHeight = (*worker)->height;
    
    size_t textureBufLength = sizeof(uint8_t) * totalWidth * totalHeight * 1;
    uint8_t *textureBuffer = (uint8_t *)calloc(textureBufLength, sizeof(uint8_t));
    unsigned int typeSettingX=0;
    unsigned int typeSettingY=0;
    unsigned int aLineHeightMax=0;
    unsigned int wholeFontHeight = (unsigned int)(face->size->metrics.height/64);
    unsigned int aLineMinCount = totalWidth/(face->size->metrics.max_advance/64);
    size_t before_cursor = page > 0 ? (*worker)->page_cursors[page-1] : 0;
    size_t now_cursor = before_cursor;
    RTOTXTRowRectArray row_rect_array;
    txt_row_rect_array_create(&row_rect_array);
    if ((*worker)->array != NULL) {
        txt_row_rect_array_destroy(&(*worker)->array);
    }
    (*worker)->array = row_rect_array;
    for (size_t i = before_cursor; i<glyph_count; i++) {
        
        hb_codepoint_t glyphid = glyph_info[i].codepoint;
        FT_Int32 flags =  FT_LOAD_DEFAULT;
        
        error = FT_Load_Glyph(face,
                              glyphid,
                              flags
                              );
        if ( error ) {
            printf("FT_Load_Glyph error code: %d",error);
        }
        
        slot = face->glyph;
        error = FT_Render_Glyph(slot, FT_RENDER_MODE_NORMAL);
        
        if ( error ) {
            printf("FT_Render_Glyph error code: %d",error);
        }
        
        FT_Bitmap bitmap = face->glyph->bitmap;
        //一个字符占位宽
        FT_Pos aCharAdvance = face->glyph->metrics.horiAdvance/64;
        FT_Pos aCharHoriBearingX = face->glyph->metrics.horiBearingX/64;
        /*
         1.大于最大宽度,换行
         2.遇到换行符,换行并继续循环
         */
        if (typeSettingX + aCharAdvance > totalWidth){
            typeSettingX = 0;
            typeSettingY += aLineHeightMax;
            aLineHeightMax = 0;
        } else if ((*worker)->codepoints[i] == '\n' ? 1 : 0) {
            typeSettingX = 0;
            typeSettingY += wholeFontHeight;
            continue;
        }
        if (typeSettingX == 0){
            RTOTXTRectArray rect_array;
            txt_rect_array_create(&rect_array);
            txt_row_rect_array_add(row_rect_array, rect_array);
        }
        
        //大于最大高度,停止
        if (typeSettingY + bitmap.rows > totalHeight){
            now_cursor = i;
            break;
        }
        
        RTOTXTRectArray rect_array = txt_row_rect_array_current(row_rect_array);
        struct RTOTXTRect_ one_rect = {typeSettingX,typeSettingY,typeSettingX+(int)aCharAdvance,typeSettingY+wholeFontHeight};
        txt_rect_array_add(rect_array, one_rect);
        //Y方向偏移量 根据字符各不相同
        unsigned int heightDelta = (unsigned int)(face->size->metrics.ascender)/64 - face->glyph->bitmap_top;
        for (unsigned int row=0; row<wholeFontHeight; row++) {
            for (unsigned int column=0; column<aCharAdvance; column++) {
                unsigned int absX = typeSettingX+column;
                unsigned int absY = row+typeSettingY;
                /**
                 * 1.垂直方向需要绘制的区域范围
                 * 2.水平方向需要绘制的区域范围
                 */
                unsigned int pixelPosition = absX+totalWidth*absY;
                if (pixelPosition>textureBufLength){
                    //此时操作的像素已经不在纹理面积里,观察一下再说
                    now_cursor = i;
                    break;
                }else if (row>heightDelta-1 && row<heightDelta+bitmap.rows && column>aCharHoriBearingX && column<aCharHoriBearingX+bitmap.width){
                    textureBuffer[pixelPosition] = bitmap.buffer[column-aCharHoriBearingX + bitmap.width*(row-heightDelta)];
                }else{
                    
                    if (heightDelta == 0 && row>0 && row<bitmap.rows && column>aCharHoriBearingX && column<aCharHoriBearingX+bitmap.width) {
                        textureBuffer[pixelPosition] = bitmap.buffer[column-aCharHoriBearingX + bitmap.width*row];
                    } else {
                        
                        //显示竖线
                        //不需要调试时加注释
//                        if (column == 0) {
//                            textureBuffer[absX+totalWidth*absY] = 255;
//                        } else {
//                            textureBuffer[absX+totalWidth*absY] = 0;
//                        }
                        
                        //显示横线
                        //                        //不需要调试时加注释
                        //                        if (row == heightDelta - 1 || row == heightDelta+bitmap.rows) {
                        //                            textureBuffer[absX+totalWidth*absY] = 255;
                        //                        } else {
                        //                            textureBuffer[absX+totalWidth*absY] = 0;
                        //                        }
                        
                        textureBuffer[absX+totalWidth*absY] = 0;
                    }
                }
            }
        }
        typeSettingX += aCharAdvance;
        
        aLineHeightMax = wholeFontHeight;
    }
    if (before_cursor == now_cursor) {
        now_cursor += glyph_count - before_cursor;
    }
    (*worker)->page_cursors[page] = now_cursor;
    return textureBuffer;
}


uint8_t *txt_worker_bitmap_next_page(RTOTXTWorker *worker)
{
    size_t page = (*worker)->current_page;
    if ((*worker)->page_cursors[page] == (*worker)->utf8_length) {
        return NULL;
    }
    
    (*worker)->current_page++;
    return txt_worker_bitmap_one_page(worker, (*worker)->current_page);
}

uint8_t *txt_worker_bitmap_previous_page(RTOTXTWorker *worker)
{
    size_t page = (*worker)->current_page;
    if (page == 0) {
        return NULL;
    }
    (*worker)->current_page--;
    return txt_worker_bitmap_one_page(worker, (*worker)->current_page);
}

void txt_rect_values(RTOTXTRect* rect, int *x, int *y, int *xx, int *yy)
{
    if (rect != NULL) {
        *x = (*rect)->x;
        *y = (*rect)->y;
        *xx = (*rect)->xx;
        *yy = (*rect)->yy;
    }
}

uint32_t* txt_worker_codepoint_in_range(RTOTXTWorker *worker, size_t start, size_t end, size_t *count)
{
    size_t length = end - start + 1;
    if (length > 0) {
        uint32_t *result = calloc(length, sizeof(uint32_t));
        for (size_t i=0; i<length; i++) {
            result[i] = (*worker)->codepoints[start+i];
        }
        *count = length;
        
        return result;
    }
    return NULL;
}

/// 指定坐标获取对应位置文字的codepoint，如果坐标对应位置有文字的话
/// @param x x坐标
/// @param y y坐标
/// @param contains 坐标包含在文字区域内
uint32_t txt_worker_codepoint_at(RTOTXTWorker *worker,int x,int y,RTOTXTRect* contains)
{
    RTOTXTRowRectArray array = (*worker)->array;
    uint32_t result = 0;
    size_t page = (*worker)->current_page;
    size_t index = page > 0 ? (*worker)->page_cursors[page-1] : 0 ;
    for (size_t i=0; i<array->count; i++) {
        RTOTXTRectArray *data = array->data;
        RTOTXTRectArray row_array = data[i];
        for (size_t j=0; j<row_array->count; j++) {
            struct RTOTXTRect_ one_rect = row_array->data[j];
            if (y >= one_rect.y && y <= one_rect.yy) {
                if (x >= one_rect.x && x <= one_rect.xx) {
                    *contains = calloc(1, sizeof(struct RTOTXTRect_));
                    (*contains)->x = one_rect.x;
                    (*contains)->y = one_rect.y;
                    (*contains)->xx = one_rect.xx;
                    (*contains)->yy = one_rect.yy;
                    result = (*worker)->codepoints[index];
                    //坐标匹配退出第二层for循环
                    break;
                }
            } else {
                //y坐标对比失败直接换下一行
                index +=row_array->count;
                break;
            }
            index +=1;
        }
        
        if (*contains) {
            //坐标匹配退出for循环
            break;
        }
    }
    
    return result;
}

void txt_worker_rect_array_from(RTOTXTWorker *worker, RTOTXTRectArray *rect_array, int sx, int sy, int ex, int ey, size_t *s_index, size_t *e_index)
{
    RTOTXTRowRectArray array = (*worker)->array;
    
    bool start_finded = false;
    bool end_finded = false;
    
    size_t page = (*worker)->current_page;
    size_t index = page > 0 ? (*worker)->page_cursors[page-1] : 0 ;
    
    for (size_t i=0; i<array->count; i++) {
        RTOTXTRectArray *data = array->data;
        RTOTXTRectArray row_array = data[i];
        for (size_t j=0; j<row_array->count; j++) {
            struct RTOTXTRect_ one_rect = row_array->data[j];
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
                                struct RTOTXTRect_ k_one_rect = row_array->data[k];
                                if (ex >= k_one_rect.x && ex <= k_one_rect.xx) {
                                    end_finded = true;
                                    
                                    struct RTOTXTRect_ result = {one_rect.x, one_rect.y, k_one_rect.xx, k_one_rect.yy};
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
                            
                            struct RTOTXTRect_ last_rect = row_array->data[row_array->count-1];
                            if (*rect_array == NULL) {
                                txt_rect_array_create(rect_array);
                            }
                            struct RTOTXTRect_ result = {one_rect.x, one_rect.y, last_rect.xx, last_rect.yy};
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
                        
                        struct RTOTXTRect_ first_rect = row_array->data[0];
                        struct RTOTXTRect_ result = {first_rect.x, first_rect.y, one_rect.xx, one_rect.yy};
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
                    struct RTOTXTRect_ first_rect = row_array->data[0];
                    struct RTOTXTRect_ last_rect = row_array->data[row_array->count-1];
                    struct RTOTXTRect_ result = {first_rect.x, first_rect.y, last_rect.xx, last_rect.yy};
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

size_t txt_worker_rect_array_get_count(RTOTXTRectArray *rect_array)
{
    return (*rect_array)->count;
}

RTOTXTRect txt_worker_rect_array_object_at(RTOTXTRectArray *rect_array, int index)
{
    return &(*rect_array)->data[index];
}

