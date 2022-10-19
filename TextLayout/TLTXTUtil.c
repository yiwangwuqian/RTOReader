//
//  TLTXTUtil.c
//  RTOReader
//
//  Created by ghy on 2021/10/30.
//  Copyright © 2021 ghy. All rights reserved.
//

#include "TLTXTUtil.h"
#include <stdio.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>

void txt_file_content(const char *path, char** content,size_t *content_len)
{
    struct stat fdstat;
    stat(path, &fdstat);
    char *buf = NULL;
    size_t buf_size;
    
    int fd;
    fd = open(path, O_RDONLY);
    /* set buffer size */
    buf_size = fdstat.st_size;
    
    /* allocate the buffer storage */
    if (buf_size > 0) {
        buf = mmap(NULL, buf_size, PROT_READ, MAP_SHARED, fd, 0);
        if (buf == MAP_FAILED) {
            close(fd);
            return;
        }
        *content = buf;
        if (content_len) {
            *content_len = buf_size;
        }
    }
}
