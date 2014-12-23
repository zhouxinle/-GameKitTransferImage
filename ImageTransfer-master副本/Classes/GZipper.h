//
//  GZipper.h
//  ShrinkyBops
//
//  Created by Alex Nichol on 11/5/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (GZipper)

// gzip compression utilities

//gzip解压
- (NSData *)gzipInflate;

//gzip压缩
- (NSData *)gzipDeflate;

@end
