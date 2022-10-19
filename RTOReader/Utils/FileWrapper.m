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

#import "FileWrapper.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import "RTOFontManager.h"

const char *GetDefaultFontPath(void)
{
#ifdef __APPLE__
    return [[RTOFontManager defaultFontPath] UTF8String];
#else
    return NULL;
#endif
}

///
/// \brief Given a fileName, convert into a path that can be used to open from
/// the mainBundle
/// \param fileName Name of file to convert to mainBundle path
/// \return Path that can be used to fopen() from the mainBundle
///
const char *GetBundleFileName( const char *fileName )
{
#ifdef __APPLE__
    NSString* fileNameNS = [NSString stringWithUTF8String:fileName];
    NSString* baseName = [fileNameNS stringByDeletingPathExtension];
    NSString* extension = [fileNameNS pathExtension];
    NSString *path = [[NSBundle mainBundle] pathForResource: baseName ofType: extension ];
    fileName = [path cStringUsingEncoding:NSUTF8StringEncoding];
    
    return fileName;
#else
    return NULL;
#endif
}

void GetScreenSize(float* width,float* height)
{
#ifdef __APPLE__
    CGSize size = [UIScreen mainScreen].bounds.size;
    *width = size.width;
    *height = size.height;
#else
#endif
}

void esWindowSize(float* width,float* height)
{
    GetScreenSize(width, height);
}

unsigned int GetScreenDpi()
{
#ifdef __APPLE__
    unsigned int dpi=0;
    float scale = 1;
    
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
        scale = [[UIScreen mainScreen] scale];
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        dpi = 132 * scale;
    } else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        dpi = 163 * scale;
    } else {
        dpi = 160 * scale;
    }
    return dpi;
#else
    return 0;
#endif
}
