//
//  TLTXTCachePage.m
//  TextLayout
//
//  Created by guohy on 2022/10/24.
//  Copyright © 2022 ghy. All rights reserved.
//

#import "TLTXTCachePage.h"
#import "TLTXTCore.h"

@interface TLTXTCachePage()

@property(nonatomic)CGSize imageSize;
@property(nonatomic)NSData *fileData;

@end

@implementation TLTXTCachePage

- (void)dealloc
{
#ifdef DEBUG
    NSLog(@"%@ dealloc", self);
#endif
    if (_rowRectArray) {
        txt_row_rect_array_destroy(&_rowRectArray);
    }
    if (_backupBytes) {
        free(_backupBytes);
    }
    if (_paragraphTailArray) {
        tl_generic_array_destroy(&_paragraphTailArray);
    }
}

- (void)setImage:(UIImage *)image
{
    _image = image;
    _imageSize = image.size;
}

- (void)saveBackup
{
    if (self.backupPath && (self.backupBytes || self.fileData)) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:self.backupPath]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:self.backupPath withIntermediateDirectories:YES attributes:NULL error:nil];
        }
        NSString *desPath = [self.backupPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld.bin",self.pageNum]];
        FILE *write_ptr;
        write_ptr = fopen([desPath UTF8String],"wb");
        NSInteger bytesCount = self.image.size.width * self.image.size.height * 4;
        void *bytes = self.backupBytes != NULL ? self.backupBytes : (void *)[self.fileData bytes];
        fwrite(bytes,1,bytesCount,write_ptr);
        fclose(write_ptr);
        
        if (_backupBytes) {
            free(_backupBytes);
            _backupBytes = NULL;
        }
        _image = nil;
    }
}

- (void)restoreBackup
{
    if (self.backupPath && !self.image && !self.backupBytes) {
        NSString *desPath = [self.backupPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld.bin",self.pageNum]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:desPath]) {
            NSData *desData = [NSData dataWithContentsOfFile:desPath];
            UIImage *image = [TLTXTCore imageWith:(uint8_t *)desData.bytes width:self.imageSize.width height:self.imageSize.height scale:1];
            self.image = image;
            self.fileData = desData;
        }
    }
}

@end
