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

#include <stdbool.h>

struct RTOTXTWorker_ {
    char *content;
    size_t utf8_length;
    
    size_t cursor;
    int width;
    int height;
    
    FT_Library    *library;
    FT_Face       face;
    hb_buffer_t   *buf;
};

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
    const char *fontPath = GetBundleFileName("站酷庆科黄油体.ttf");
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
            
            hb_font_t *font = hb_ft_font_create_referenced(face);
            hb_shape(font, buf, NULL, 0);
            
            object->width = width;
            object->height = height;
            
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

uint8_t *txt_worker_bitmap_onepage(RTOTXTWorker *worker)
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
    size_t before_cursor = (*worker)->cursor;
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
        //大于最大宽度,换行
        if (typeSettingX + aCharAdvance > totalWidth){
            typeSettingX = 0;
            typeSettingY += aLineHeightMax;
            aLineHeightMax = 0;
        }
        //大于最大高度,停止
        if (typeSettingY + bitmap.rows > totalHeight){
            (*worker)->cursor = i;
            break;
        }
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
                    (*worker)->cursor = i;
                    break;
                }else if (row>heightDelta-1 && row<heightDelta+bitmap.rows && column>aCharHoriBearingX && column<aCharHoriBearingX+bitmap.width){
                    textureBuffer[pixelPosition] = bitmap.buffer[column-aCharHoriBearingX + bitmap.width*(row-heightDelta)];
                }else{
                    
                    if (heightDelta == 0 && row>0 && row<bitmap.rows && column>aCharHoriBearingX && column<aCharHoriBearingX+bitmap.width) {
                        textureBuffer[pixelPosition] = bitmap.buffer[column-aCharHoriBearingX + bitmap.width*row];
                    } else {
                        //不需要调试时加注释
                        if (row == heightDelta - 1 || row == heightDelta+bitmap.rows) {
                            textureBuffer[absX+totalWidth*absY] = 255;
                        } else {
                            textureBuffer[absX+totalWidth*absY] = 0;
                        }
//                        textureBuffer[absX+totalWidth*absY] = 0;
                    }
                }
            }
        }
        typeSettingX += aCharAdvance;
        
        aLineHeightMax = wholeFontHeight;
    }
    if (before_cursor == (*worker)->cursor) {
        (*worker)->cursor += glyph_count - (*worker)->cursor;
    }
    return textureBuffer;
}
