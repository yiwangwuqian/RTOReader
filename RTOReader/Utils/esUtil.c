// The MIT License (MIT)
//
// Copyright (c) 2013 Dan Ginsburg, Budirijanto Purnomo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

//
// Book:      OpenGL(R) ES 3.0 Programming Guide, 2nd Edition
// Authors:   Dan Ginsburg, Budirijanto Purnomo, Dave Shreiner, Aaftab Munshi
// ISBN-10:   0-321-93388-5
// ISBN-13:   978-0-321-93388-1
// Publisher: Addison-Wesley Professional
// URLs:      http://www.opengles-book.com
//            http://my.safaribooksonline.com/book/animation-and-3d/9780133440133
//
// ESUtil.c
//
//    A utility library for OpenGL ES.  This library provides a
//    basic common framework for the example applications in the
//    OpenGL ES 3.0 Programming Guide.
//

///
//  Includes
//
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include "esUtil.h"

#ifdef __APPLE__
#include "FileWrapper.h"
#endif

#include <math.h>
#include <ft2build.h>
#include FT_FREETYPE_H

uint8_t *hbBitmapFrom(char *text, int width, int height)
{
    FT_Library    library;
    FT_Face       face;

    FT_GlyphSlot  slot;
    FT_Error      error;

    error = FT_Init_FreeType( &library );              /* initialize library */
    /* error handling omitted */
    const char *fontPath = GetBundleFileName("站酷庆科黄油体.ttf");
    
    hb_buffer_t *buf;
    buf = hb_buffer_create();
    hb_buffer_add_utf8(buf, text, -1, 0, -1);
    
    hb_buffer_set_direction(buf, HB_DIRECTION_LTR);
    //hb_buffer_set_script(buf, HB_SCRIPT_LATIN);
    //hb_buffer_set_language(buf, hb_language_from_string("en", -1));
    hb_buffer_set_script(buf, HB_SCRIPT_HAN);
    hb_buffer_set_language(buf, hb_language_from_string("ch", -1));
    
    error = FT_New_Face( library, fontPath, 0, &face );/* create face object */
    /* error handling omitted */
    
    unsigned int screenDpi = GetScreenDpi();
    
    /* use 50pt at 100dpi */
    error = FT_Set_Char_Size( face,
                             40/1136.0*screenDpi * 64,
                             0,
                             screenDpi,
                             0 );                /* set character size */

    hb_font_t *font = hb_ft_font_create_referenced(face);
    hb_shape(font, buf, NULL, 0);
    unsigned int glyph_count;
    hb_glyph_info_t *glyph_info = hb_buffer_get_glyph_infos(buf, &glyph_count);
    hb_glyph_position_t *glyph_pos = hb_buffer_get_glyph_positions(buf, &glyph_count);
    
    unsigned int totalWidth=0;
    unsigned int totalHeight=0;
    totalWidth = width;
    totalHeight = height;
    
    size_t textureBufLength = sizeof(uint8_t) * totalWidth * totalHeight * 1;
    uint8_t *textureBuffer = (uint8_t *)calloc(textureBufLength, sizeof(uint8_t));
    unsigned int typeSettingX=0;
    unsigned int typeSettingY=0;
    unsigned int aLineHeightMax=0;
    unsigned int wholeFontHeight = (unsigned int)(face->size->metrics.height/64);
    unsigned int aLineMinCount = totalWidth/(face->size->metrics.max_advance/64);
    for (size_t i = 0; i<glyph_count; i++) {
        
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
    
    
    hb_buffer_destroy(buf);
    hb_font_destroy(font);
    
    FT_Done_Face    ( face );
    FT_Done_FreeType( library );
    return textureBuffer;
}

uint8_t *hbBitmapFrom2(char *text, size_t start, size_t *end, int width, int height)
{
    FT_Library    library;
    FT_Face       face;

    FT_GlyphSlot  slot;
    FT_Error      error;

    error = FT_Init_FreeType( &library );              /* initialize library */
    /* error handling omitted */
    const char *fontPath = GetBundleFileName("站酷庆科黄油体.ttf");
    
    hb_buffer_t *buf;
    buf = hb_buffer_create();
    if (start > 0) {
        char *des_text = calloc(sizeof(char) * (strlen(text) - start), sizeof(char));
        memcpy(des_text, text+start, strlen(text) - start);
        hb_buffer_add_utf8(buf, des_text, -1, 0, -1);
        free(des_text);
    } else {
        hb_buffer_add_utf8(buf, text, -1, 0, -1);
    }
    
    hb_buffer_set_direction(buf, HB_DIRECTION_LTR);
    //hb_buffer_set_script(buf, HB_SCRIPT_LATIN);
    //hb_buffer_set_language(buf, hb_language_from_string("en", -1));
    hb_buffer_set_script(buf, HB_SCRIPT_HAN);
    hb_buffer_set_language(buf, hb_language_from_string("ch", -1));
    
    error = FT_New_Face( library, fontPath, 0, &face );/* create face object */
    /* error handling omitted */
    
    unsigned int screenDpi = GetScreenDpi();
    
    /* use 50pt at 100dpi */
    error = FT_Set_Char_Size( face,
                             40/1136.0*screenDpi * 64,
                             0,
                             screenDpi,
                             0 );                /* set character size */

    hb_font_t *font = hb_ft_font_create_referenced(face);
    hb_shape(font, buf, NULL, 0);
    unsigned int glyph_count;
    hb_glyph_info_t *glyph_info = hb_buffer_get_glyph_infos(buf, &glyph_count);
    hb_glyph_position_t *glyph_pos = hb_buffer_get_glyph_positions(buf, &glyph_count);
    
    unsigned int totalWidth=0;
    unsigned int totalHeight=0;
    totalWidth = width;
    totalHeight = height;
    
    size_t textureBufLength = sizeof(uint8_t) * totalWidth * totalHeight * 1;
    uint8_t *textureBuffer = (uint8_t *)calloc(textureBufLength, sizeof(uint8_t));
    unsigned int typeSettingX=0;
    unsigned int typeSettingY=0;
    unsigned int aLineHeightMax=0;
    unsigned int wholeFontHeight = (unsigned int)(face->size->metrics.height/64);
    unsigned int aLineMinCount = totalWidth/(face->size->metrics.max_advance/64);
    for (size_t i = 0; i<glyph_count; i++) {
        
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
            *end = start+i+1;
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
                    *end = start+i+1;
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
    
    
    hb_buffer_destroy(buf);
    hb_font_destroy(font);
    
    FT_Done_Face    ( face );
    FT_Done_FreeType( library );
    return textureBuffer;
}

char *getBundleFileContent(const char *name)
{
    FILE *fp = fopen(GetBundleFileName(name), "r");
    if (fp == NULL){
        return "";
    }
    fseek(fp,0L,SEEK_END);
    long flen=ftell(fp);
    char *result=(char *)malloc(flen+1);
    fseek(fp,0L,SEEK_SET);
    fread(result, 1, flen+1, fp);
    
    return result;
}
