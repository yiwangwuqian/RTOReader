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

void txt_color_split_from(size_t color, size_t *r, size_t *g, size_t*b);

TLTXTAttributes txt_attributes_check_range(TLRangeArray rArray, TLTXTAttributesArray aArray, size_t index, int64_t *output_last_range_index);

unsigned int txt_worker_check_oneline_max_height(FT_Face face,
                                                 hb_glyph_info_t *glyph_info,
                                                 unsigned int glyph_count,
                                                 size_t start_cursor,
                                                 TLRangeArray rArray,
                                                 TLTXTAttributesArray aArray,
                                                 int64_t *last_range_index,
                                                 bool change_last_range_index,
                                                 unsigned int totalWidth,
                                                 hb_codepoint_t *codepoints,
                                                 unsigned int *max_ascender,
                                                 unsigned int *oneline_count);
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
    TLTXTWorker_DefaultAttributesFunc default_attributes_func;
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

void txt_worker_create(TLTXTWorker *worker, const char *text, int width, int height)
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

void txt_worker_set_default_attributes_callback(TLTXTWorker worker, TLTXTWorker_DefaultAttributesFunc func)
{
    if (worker != NULL) {
        worker->default_attributes_func = func;
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
    
    unsigned int wholeFontHeight = (unsigned int)(face->size->metrics.height/64);
    
    size_t before_cursor = 0;
    size_t now_cursor = 0;
    
    TLRangeArray rArray = NULL;
    TLTXTAttributesArray aArray = NULL;
    if ((*worker)->range_attributes_func) {
        struct TLRange_ page_range = {0, glyph_count};
        (*worker)->range_attributes_func(*worker, &page_range, &rArray, &aArray);
    }
    TLTXTAttributes defaultAttributes = NULL;
    if ((*worker)->default_attributes_func) {
        defaultAttributes = (*worker)->default_attributes_func(*worker);
    }
    size_t range_total_count = rArray != NULL ? tl_range_array_get_count(rArray) : 0;
    int64_t last_range_index = range_total_count > 0 ? 0 : -1;
    int64_t backup_last_range_index = last_range_index;
    
    while (glyph_count != now_cursor) {
        
        unsigned int typeSettingY=0;
        unsigned int aLineHeightMax=0;
        unsigned int aLineAscenderMax=0;
        
        before_cursor = now_cursor;
        
        size_t i = before_cursor;
        while (i<glyph_count) {
            backup_last_range_index = last_range_index;
            
            unsigned int oneline_count = 0;
            aLineHeightMax = txt_worker_check_oneline_max_height(face,
                                                                 glyph_info,
                                                                 glyph_count,
                                                                 i,
                                                                 rArray,
                                                                 aArray,
                                                                 &last_range_index,
                                                                 true,
                                                                 totalWidth,
                                                                 (*worker)->codepoints,
                                                                 &aLineAscenderMax,
                                                                 &oneline_count);
            
            if (!oneline_count) {
                //目前只有首个字是换行符这种情况
                i++;
            }
            
            //oneline_count==0时会出现
            if (aLineHeightMax == 0) {
                aLineHeightMax = wholeFontHeight;
            }
            
            size_t line_spacing = 0;
            if (defaultAttributes && defaultAttributes->lineSpacing > 0) {
                line_spacing = defaultAttributes->lineSpacing;
            }
            
            //无论这一行是多少字 Y坐标都要下移
            if (typeSettingY + aLineHeightMax + line_spacing > totalHeight){
                //大于最大高度,停止 恢复last_range_index
                now_cursor = i;
                last_range_index = backup_last_range_index;
                break;
            } else {
                typeSettingY += aLineHeightMax + line_spacing;
                i += oneline_count;
            }
            
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
    
    if (rArray) {
        tl_range_array_destroy(&rArray);
    }
    if (aArray) {
        tl_txt_attributes_array_destroy(&aArray);
    }
    if (defaultAttributes) {
        free(defaultAttributes);
    }
    
    (*worker)->total_page = page;
}

size_t txt_worker_total_page(TLTXTWorker *worker)
{
    return (*worker)->total_page;
}

uint8_t *txt_worker_bitmap_one_page(TLTXTWorker *worker, size_t page,TLTXTRowRectArray *page_row_rect_array)
{
    if ( page >= (*worker)->total_page ) {
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
    
    unsigned int totalWidth=0;
    unsigned int totalHeight=0;
    totalWidth = (*worker)->width;
    totalHeight = (*worker)->height;
    
    size_t texturePixelCount = sizeof(uint8_t) * totalWidth * totalHeight * 1;
    uint8_t *textureBuffer = (uint8_t *)calloc(texturePixelCount*4, sizeof(uint8_t));
    unsigned int typeSettingX=0;
    unsigned int typeSettingY=0;
    unsigned int aLineHeightMax=0;
    unsigned int aLineAscenderMax=0;
    unsigned int wholeFontAscenderMax = (unsigned int)(face->size->metrics.ascender)/64;
    unsigned int wholeFontHeight = (unsigned int)(face->size->metrics.height/64);
    size_t before_cursor = page > 0 ? (*(*worker)->cursor_array).data[page-1] : 0;
    
    TLRangeArray rArray = NULL;
    TLTXTAttributesArray aArray = NULL;
    struct TLRange_ checkedLineRange = {0,0};
    if ((*worker)->range_attributes_func) {
        size_t next_cursor = page < (*worker)->total_page ? (*(*worker)->cursor_array).data[page] : glyph_count-1;
        struct TLRange_ page_range = {before_cursor, next_cursor-before_cursor};
        (*worker)->range_attributes_func(*worker, &page_range, &rArray, &aArray);
    }
    TLTXTAttributes defaultAttributes = NULL;
    if ((*worker)->default_attributes_func) {
        defaultAttributes = (*worker)->default_attributes_func(*worker);
    }
    
    size_t range_total_count = rArray != NULL ? tl_range_array_get_count(rArray) : 0;
    int64_t last_range_index = range_total_count > 0 ? 0 : -1;
    size_t last_red = 0;
    size_t last_green = 0;
    size_t last_blue = 0;
    
    size_t now_cursor = before_cursor;
    TLTXTRowRectArray row_rect_array;
    txt_row_rect_array_create(&row_rect_array);
    *page_row_rect_array = row_rect_array;
    for (size_t i = before_cursor; i<(*(*worker)->cursor_array).data[page]; i++) {
        unsigned int beforeALineHeightMax = aLineHeightMax;
        
        size_t checkedLineRangeMax = checkedLineRange.location + checkedLineRange.length;
        if (typeSettingX == 0 || (checkedLineRange.length != 0 && checkedLineRangeMax == i)){
            if (last_range_index >= 0 && last_range_index < range_total_count) {
                unsigned int oneline_count = 0;
                aLineHeightMax = txt_worker_check_oneline_max_height(face,
                                                                     glyph_info,
                                                                     glyph_count,
                                                                     i,
                                                                     rArray,
                                                                     aArray,
                                                                     &last_range_index,
                                                                     false,
                                                                     totalWidth,
                                                                     (*worker)->codepoints,
                                                                     &aLineAscenderMax,
                                                                     &oneline_count);
                checkedLineRange.location = i;
                checkedLineRange.length = oneline_count;
            } else {
                aLineHeightMax = wholeFontHeight;
                aLineAscenderMax = wholeFontAscenderMax;
            }
        }
        
        if (last_range_index >= 0 && last_range_index < range_total_count) {
            TLTXTAttributes onceAttributes = txt_attributes_check_range(rArray, aArray, i, &last_range_index);
            if (onceAttributes && onceAttributes->color) {
                txt_color_split_from(onceAttributes->color, &last_red, &last_green, &last_blue);
            } else {
                last_red = 0;
                last_green = 0;
                last_blue = 0;
            }
            if (onceAttributes && onceAttributes->fontSize) {
                FT_Set_Pixel_Sizes(face, 0, onceAttributes->fontSize);
            } else {
                FT_Set_Pixel_Sizes(face, 0, GetDeviceFontSize(21));
            }
        }
        
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
        
        size_t line_spacing = 0;
        if (defaultAttributes && defaultAttributes->lineSpacing > 0) {
            line_spacing = defaultAttributes->lineSpacing;
        }
        
        /*
         以下这个if else if判断的作用在于检查是否修改Y坐标，或进行下一个字的绘制
         1.大于最大宽度,换行
         2.遇到换行符,换行并继续循环
         
         循环刚开始的时候在文本有属性的情况下，调用了txt_worker_check_oneline_max_height
         这个方法的执行个人认为最好在文本没有属性的情况下不调用，能避免一些耗时
         */
        if (typeSettingX + aCharAdvance > totalWidth){
            typeSettingX = 0;
            typeSettingY += beforeALineHeightMax + line_spacing;
        } else if ((*worker)->codepoints[i] == '\n' ? 1 : 0) {
            if (typeSettingX == 0) {
                /**
                 *如果当前第一个字是换行符，它上一个字是换行即'\n'，它要单独占一行
                 *无论上一个字是什么都需要continue
                 */
                if ((i > 0 && (*worker)->codepoints[i-1] == '\n') || i==0) {
                    typeSettingY += (beforeALineHeightMax > 0 ? beforeALineHeightMax : wholeFontHeight) + line_spacing;
                }
                continue;
            } else {
                typeSettingX = 0;
                typeSettingY += beforeALineHeightMax + line_spacing;
                continue;
            }
        }
        if (typeSettingX == 0){
            TLTXTRectArray rect_array;
            txt_rect_array_create(&rect_array);
            txt_row_rect_array_add(row_rect_array, rect_array);
        }
        
        //大于最大高度,停止
        if (typeSettingY + aLineHeightMax > totalHeight){
            now_cursor = i;
            break;
        }
        
        TLTXTRectArray rect_array = txt_row_rect_array_current(row_rect_array);
        struct TLTXTRect_ one_rect = {typeSettingX,typeSettingY,typeSettingX+(int)aCharAdvance,typeSettingY+aLineHeightMax};
        txt_rect_array_add(rect_array, one_rect);
        //Y方向偏移量 根据字符各不相同
        unsigned int heightDelta = aLineAscenderMax - face->glyph->bitmap_top;
        for (unsigned int row=0; row<aLineHeightMax; row++) {
            for (unsigned int column=0; column<aCharAdvance; column++) {
                unsigned int absX = typeSettingX+column;
                unsigned int absY = row+typeSettingY;
                /**
                 * 1.垂直方向需要绘制的区域范围
                 * 2.水平方向需要绘制的区域范围
                 */
                unsigned int pixelPosition = absX+totalWidth*absY;
                if (pixelPosition>texturePixelCount){
                    //此时操作的像素已经不在纹理面积里,观察一下再说
                    now_cursor = i;
                    break;
                }else if (row>heightDelta-1 && row<heightDelta+bitmap.rows && column>aCharHoriBearingX && column<aCharHoriBearingX+bitmap.width){
                    unsigned char pixelValue = bitmap.buffer[column-aCharHoriBearingX + bitmap.width*(row-heightDelta)];
                    //这样设置即bitmap上没有内容的像素点rgb为0x000000
                    if (pixelValue) {
                        textureBuffer[pixelPosition*4] = last_red;
                        textureBuffer[pixelPosition*4+1] = last_green;
                        textureBuffer[pixelPosition*4+2] = last_blue;
                        textureBuffer[pixelPosition*4+3] = pixelValue;
                    }
                }else{
                    
                    if (heightDelta == 0 && row>0 && row<bitmap.rows && column>aCharHoriBearingX && column<aCharHoriBearingX+bitmap.width) {
                        unsigned char pixelValue = bitmap.buffer[column-aCharHoriBearingX + bitmap.width*row];
                        //这样设置即bitmap上没有内容的像素点rgb为0x000000
                        if (pixelValue) {
                            textureBuffer[pixelPosition*4] = last_red;
                            textureBuffer[pixelPosition*4+1] = last_green;
                            textureBuffer[pixelPosition*4+2] = last_blue;
                            textureBuffer[pixelPosition*4+3] = pixelValue;
                        }
                    } else {
                        
                        //显示竖线
                        //不需要调试时加注释
//                        if (column == 0) {
//                            textureBuffer[absX+totalWidth*absY] = 255;
//                        } else {
//                            textureBuffer[absX+totalWidth*absY] = 0;
//                        }
                        
                        //显示横线
                        //不需要调试时加注释
                        /*
                        if (row == heightDelta - 1 || row == heightDelta+bitmap.rows) {
                            textureBuffer[pixelPosition*4+3] = 255;
                        } else {
                            textureBuffer[pixelPosition*4] = 255;
                            textureBuffer[pixelPosition*4+1] = 255;
                            textureBuffer[pixelPosition*4+2] = 255;
                            textureBuffer[pixelPosition*4+3] = 255;
                        }
                         */
                        
                        //这个赋值对应的是每行第一个字到最后一个字之间空白的部分
                        /*
                        textureBuffer[pixelPosition*4] = 255;
                        textureBuffer[pixelPosition*4+1] = 255;
                        textureBuffer[pixelPosition*4+2] = 255;
                        textureBuffer[pixelPosition*4+3] = 255;
                         */
                    }
                }
            }
        }
        typeSettingX += aCharAdvance;
        
        if (now_cursor != before_cursor) {
            break;
        }
    }
    if (before_cursor == now_cursor) {
        now_cursor += glyph_count - before_cursor;
    }
    if (rArray) {
        tl_range_array_destroy(&rArray);
    }
    if (aArray) {
        tl_txt_attributes_array_destroy(&aArray);
    }
    if (defaultAttributes) {
        free(defaultAttributes);
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

void txt_color_split_from(size_t color, size_t *r, size_t *g, size_t*b)
{
    int32_t c = (int32_t)color;
    *r = (c >> 16) & 0xFF;
    *g = (c >> 8) & 0xFF;
    *b = (c) & 0xFF;
}

TLTXTAttributes txt_attributes_check_range(TLRangeArray rArray, TLTXTAttributesArray aArray, size_t index, int64_t *output_last_range_index)
{
    TLTXTAttributes result = NULL;
    size_t range_total_count = tl_range_array_get_count(rArray);
    int64_t last_range_index = *output_last_range_index;
    
    while (last_range_index >=0 && last_range_index < range_total_count) {
        TLRange onceRange = tl_range_array_object_at(rArray, last_range_index);
        size_t locationSumLength = onceRange->location+onceRange->length;
        if (onceRange->location <= index && index < locationSumLength) {
            TLTXTAttributes onceAttributes = tl_txt_attributes_array_object_at(aArray, last_range_index);
            result = onceAttributes;
            break;
        } else {
            //只有在刚出了onceRange的范围时才递增
            if (index == locationSumLength) {
                last_range_index++;
            } else {
                break;
            }
        }
    }
    *output_last_range_index = last_range_index;
    return result;
}

unsigned int txt_worker_check_oneline_max_height(FT_Face face,
                                                 hb_glyph_info_t *glyph_info,
                                                 unsigned int glyph_count,
                                                 size_t start_cursor,
                                                 TLRangeArray rArray,
                                                 TLTXTAttributesArray aArray,
                                                 int64_t *last_range_index,
                                                 bool change_last_range_index,
                                                 unsigned int totalWidth,
                                                 hb_codepoint_t *codepoints,
                                                 unsigned int *max_ascender,
                                                 unsigned int *oneline_count)
{
    unsigned int typeSettingX=0;
    unsigned int onelineMaxHeight=0;
    unsigned int onelineMaxAscender=0;
    unsigned int oneLineCharCount = 0;
    int64_t inner_last_range_index = *last_range_index;
    //默认size
    FT_Set_Pixel_Sizes(face, 0, GetDeviceFontSize(21));
    for (size_t i = start_cursor; i<glyph_count; i++) {
        if (inner_last_range_index >= 0) {
            TLTXTAttributes onceAttributes = txt_attributes_check_range(rArray, aArray, i, &inner_last_range_index);
            if (onceAttributes && onceAttributes->fontSize) {
                FT_Set_Pixel_Sizes(face, 0, onceAttributes->fontSize);
            } else {
                FT_Set_Pixel_Sizes(face, 0, GetDeviceFontSize(21));
            }
        }

        hb_codepoint_t glyphid = glyph_info[i].codepoint;
        FT_Int32 flags =  FT_LOAD_DEFAULT;
        
        /* load glyph image into the slot without rendering */
        FT_Error error = FT_Load_Glyph(face,
                                       glyphid,
                                       flags
                                       );
        
        if ( error ) {
            printf("FT_Load_Glyph error code: %d",error);
        }

        FT_Pos aCharAdvance = face->glyph->metrics.horiAdvance/64;
        if (typeSettingX + aCharAdvance > totalWidth){
            oneLineCharCount = (unsigned int)(i - start_cursor);
            break;
        } else if (codepoints[i] == '\n' ? 1 : 0) {
            unsigned int countFromStart = (unsigned int)(i - start_cursor);
            /**
             *如果第一个字是换行 那么oneLineCharCount此时等于0
             *如果它上一个字不是换行即'\n'，那么它不占位置需要continue，否则它要单独占一行。
             */
            if (countFromStart == 0) {
                if (i > 0 && codepoints[i-1] != '\n') {
                    continue;
                }
            }
            //注意:必须加1下一次从这个换行符之后开始
            oneLineCharCount = countFromStart + 1;
            break;
        }

        unsigned int wholeFontHeight = (unsigned int)(face->size->metrics.height)/64;
        unsigned int wholeFontAscender = (unsigned int)(face->size->metrics.ascender)/64;
        
        if (wholeFontHeight > onelineMaxHeight) {
            onelineMaxHeight = wholeFontHeight;
        }
        if (wholeFontAscender > onelineMaxAscender) {
            onelineMaxAscender = wholeFontAscender;
        }

        typeSettingX += aCharAdvance;
    }
    *max_ascender = onelineMaxAscender;
    //这一行有内容但是没有换行，此时到了内容的末尾
    if (typeSettingX > 0 && oneLineCharCount == 0) {
        oneLineCharCount = (unsigned int)(glyph_count - start_cursor);
    }
    *oneline_count = oneLineCharCount;
    if (change_last_range_index) {
        *last_range_index = inner_last_range_index;
    }
    return onelineMaxHeight;
}
