//
//  TLTXTWorker.c
//  RTOReader
//
//  Created by ghy on 2021/6/15.
//  Copyright © 2021 ghy. All rights reserved.
//

#include "TLTXTWorker.h"
#include "FileWrapper.h"

#include <ft2build.h>
#include FT_FREETYPE_H

#include "hb-ft.h"

#include "TLTXTTypes.h"

typedef struct RTOTXTPageCursorArray_* RTOTXTPageCursorArray;

//------Private methods
void txt_page_cursor_array_create(RTOTXTPageCursorArray *array);

bool txt_page_cursor_array_add(struct RTOTXTPageCursorArray_ *array,size_t cursor);

void txt_page_cursor_array_destroy(RTOTXTPageCursorArray *array);

//------

struct TLTXTWorker_ {
    char *content;
    size_t utf8_length;
    
    size_t cursor;
    
    int width;
    int height;
    
    FT_Library    library;
    FT_Face       face;
    hb_buffer_t   *buf;
    hb_font_t     *font;
    hb_codepoint_t *codepoints;
    TLTXTRowRectArray array;
    
    size_t current_page;
    
    size_t total_page;//总页数
    RTOTXTPageCursorArray cursor_array;
    
    TLTXTWorker_RangeAttributesFunc range_attributes_func;
    void *context;
};

//------RTOTXTPageCursorArray_ 数组只有创建、新增元素、销毁操作
struct RTOTXTPageCursorArray_ {
    size_t *data;
    size_t length;//真实长度
    size_t count;//元素个数
};

void txt_page_cursor_array_create(RTOTXTPageCursorArray *array)
{
    RTOTXTPageCursorArray object = calloc(1, sizeof(struct RTOTXTPageCursorArray_));
    
    size_t length = 100;
    object->length = length;
    object->data = calloc(length, sizeof(size_t));
    
    *array = object;
}

bool txt_page_cursor_array_add(struct RTOTXTPageCursorArray_ *array,size_t cursor)
{
    if( !((*array).count < (*array).length) ) {
        size_t length = (*array).length + 100;
        size_t *data = realloc((*array).data, length*sizeof(size_t));
        if (data == NULL) {
            return false;
        }
        (*array).data = data;
        (*array).length = length;
    }
    (*array).data[(*array).count] = cursor;
    (*array).count+=1;
    return true;
}

void txt_page_cursor_array_destroy(RTOTXTPageCursorArray *array)
{
    free((*array)->data);
    free(*array);
    *array = NULL;
}

//------

bool txt_worker_previous_able(TLTXTWorker *worker)
{
    return false;
}

bool txt_worker_next_able(TLTXTWorker *worker)
{
    if ((*worker)->utf8_length == (*worker)->cursor) {
        return false;
    }
    
    return true;
}

void txt_worker_create(TLTXTWorker *worker, char *text, int width, int height)
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
            
            TLTXTWorker object = calloc(1, sizeof(struct TLTXTWorker_));
            object->library = library;
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
            object->font = font;
            hb_shape(font, buf, NULL, 0);
            
            object->width = width;
            object->height = height;
            
            txt_page_cursor_array_create(&object->cursor_array);
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

void txt_worker_set_range_attributes_callback(TLTXTWorker worker, TLTXTWorker_RangeAttributesFunc func)
{
    if (worker != NULL) {
        worker->range_attributes_func = func;
    }
}

void txt_worker_set_context(TLTXTWorker worker, void *context)
{
    if (worker != NULL) {
        worker->context = context;
    }
}

void *txt_worker_get_context(TLTXTWorker worker)
{
    if (worker != NULL) {
        return worker->context;
    }
    return NULL;
}

void txt_worker_destroy(TLTXTWorker *worker)
{
    TLTXTWorker object = *worker;
    hb_buffer_destroy(object->buf);
    hb_font_destroy(object->font);
    FT_Done_Face    (object->face);
    FT_Done_FreeType(object->library);
    free(object->codepoints);
    if (object->cursor_array != NULL) {
        txt_page_cursor_array_destroy(&object->cursor_array);
    }
    free(object);
    *worker = NULL;
}

void txt_worker_data_paging(TLTXTWorker *worker)
{
    /**
     *实现目标：
     *1.计算出来共有多少页
     *2.同时每页有多少字，即当页内容的范围
     */
    
    size_t page = 0;
    
    FT_Face       face = (*worker)->face;
    FT_Set_Pixel_Sizes(face, 0, GetDeviceFontSize(21));
    hb_buffer_t *buf = (*worker)->buf;
    
    unsigned int glyph_count;
    hb_glyph_info_t *glyph_info = hb_buffer_get_glyph_infos(buf, &glyph_count);
    
    unsigned int totalWidth=0;
    unsigned int totalHeight=0;
    totalWidth = (*worker)->width;
    totalHeight = (*worker)->height;
    
    size_t textureBufLength = sizeof(uint8_t) * totalWidth * totalHeight * 1;
    
    size_t before_cursor = 0;
    size_t now_cursor = 0;
    
    while (glyph_count != now_cursor) {
        
        FT_GlyphSlot  slot;
        FT_Error      error;
        
        unsigned int typeSettingX=0;
        unsigned int typeSettingY=0;
        unsigned int aLineHeightMax=0;
        unsigned int wholeFontHeight = (unsigned int)(face->size->metrics.height/64);
        
        before_cursor = now_cursor;
        
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
            
            //一个字符占宽高
            FT_Pos aCharAdvance = face->glyph->metrics.horiAdvance/64;//作为宽度使用
            
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
            
            //大于最大高度,停止
            if (typeSettingY + face->glyph->metrics.height/64 > totalHeight){
                now_cursor = i;
                break;
            }

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
                    }
                }
            }
            typeSettingX += aCharAdvance;
            
            aLineHeightMax = wholeFontHeight;
            if (now_cursor != before_cursor) {
                break;
            }
        }
        if (before_cursor == now_cursor) {
            now_cursor += glyph_count - before_cursor;
        }
        
        txt_page_cursor_array_add((*worker)->cursor_array, now_cursor);
        //此处是循环的结尾
        page++;
    }
    
    (*worker)->total_page = page;
}

size_t txt_worker_total_page(TLTXTWorker *worker)
{
    return (*worker)->total_page;
}

uint8_t *txt_worker_bitmap_one_page(TLTXTWorker *worker, size_t page,TLTXTRowRectArray *page_row_rect_array)
{
    if (!txt_worker_next_able(worker)) {
        return NULL;
    }
    
    FT_Face       face = (*worker)->face;
    
    FT_GlyphSlot  slot;
    FT_Error      error;
    
    hb_buffer_t *buf = (*worker)->buf;
    
    
    //First method to set font size
//    unsigned int screenDpi = GetScreenDpi();
//
//    /* use 50pt at 100dpi */
//    error = FT_Set_Char_Size( face,
//                             40/1136.0*screenDpi * 64,
//                             0,
//                             screenDpi,
//                             0 );                /* set character size */
    
    //Second method to set font size
    FT_Set_Pixel_Sizes(face, 0, GetDeviceFontSize(21));
    
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
    size_t before_cursor = page > 0 ? (*(*worker)->cursor_array).data[page-1] : 0;
    
    TLRangeArray rArray;
    TLTXTAttributesArray aArray;
    if ((*worker)->range_attributes_func) {
        size_t next_cursor = page < (*worker)->total_page ? (*(*worker)->cursor_array).data[page] : glyph_count-1;
        struct TLRange_ page_range = {before_cursor, next_cursor-before_cursor};
        (*worker)->range_attributes_func(*worker, &page_range, &rArray, &aArray);
    }
    
    size_t now_cursor = before_cursor;
    TLTXTRowRectArray row_rect_array;
    txt_row_rect_array_create(&row_rect_array);
    *page_row_rect_array = row_rect_array;
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
//        printf("bitmap.rows:%d face->glyph->metrics.height/64:%ld\n", bitmap.rows, face->glyph->metrics.height/64);
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
            TLTXTRectArray rect_array;
            txt_rect_array_create(&rect_array);
            txt_row_rect_array_add(row_rect_array, rect_array);
        }
        
        //大于最大高度,停止
        if (typeSettingY + bitmap.rows > totalHeight){
            now_cursor = i;
            break;
        }
        
        TLTXTRectArray rect_array = txt_row_rect_array_current(row_rect_array);
        struct TLTXTRect_ one_rect = {typeSettingX,typeSettingY,typeSettingX+(int)aCharAdvance,typeSettingY+wholeFontHeight};
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
        if (now_cursor != before_cursor) {
            break;
        }
    }
    if (before_cursor == now_cursor) {
        now_cursor += glyph_count - before_cursor;
    }
    return textureBuffer;
}

uint32_t* txt_worker_codepoint_in_range(TLTXTWorker *worker, size_t start, size_t end, size_t *count)
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
uint32_t txt_worker_codepoint_at(TLTXTWorker *worker,int x,int y,TLTXTRect* contains)
{
    TLTXTRowRectArray array = (*worker)->array;
    uint32_t result = 0;
    size_t page = (*worker)->current_page;
    size_t index = page > 0 ? (*(*worker)->cursor_array).data[page-1] : 0 ;
    for (size_t i=0; i<array->count; i++) {
        TLTXTRectArray *data = array->data;
        TLTXTRectArray row_array = data[i];
        for (size_t j=0; j<row_array->count; j++) {
            struct TLTXTRect_ one_rect = row_array->data[j];
            if (y >= one_rect.y && y <= one_rect.yy) {
                if (x >= one_rect.x && x <= one_rect.xx) {
                    *contains = calloc(1, sizeof(struct TLTXTRect_));
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

size_t txt_worker_page_cursor_array_get(TLTXTWorker worker,size_t page)
{
    RTOTXTPageCursorArray array = worker->cursor_array;
    return array->data[page];
}
