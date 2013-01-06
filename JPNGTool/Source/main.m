//
//  JPNGTool
//
//  Version 1.0
//
//  Created by Nick Lockwood on 05/01/2013.
//  Copyright 2013 Charcoal Design
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/JPNG
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import <AppKit/AppKit.h>
#import "JPNG.h"


int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        if (argc == 1)
        {
            NSLog(@"JPNGTool arguments: inputfile [outputfile] [quality]");
            return 0;
        }
        
        //input file
        NSString *inputFile = [NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding];
        if (![[NSFileManager defaultManager] fileExistsAtPath:inputFile])
        {
            NSLog(@"Input file '%@' does not exist", inputFile);
            return 0;
        }
        
        //output file
        NSString *outputFile = [[inputFile stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpng"];
        if (argc > 2)
        {
            outputFile = [NSString stringWithCString:argv[2] encoding:NSUTF8StringEncoding];
            if (![[NSFileManager defaultManager] fileExistsAtPath:inputFile])
            {
                NSLog(@"Input file '%@' does not exist", inputFile);
                return 0;
            }
        }
        
        //quality
        float quality = 0.8f;
        if (argc > 3)
        {
            quality = [[NSString stringWithCString:argv[3] encoding:NSUTF8StringEncoding] floatValue];
            if (quality <= 0.0f || quality > 1.0f)
            {
                NSLog(@"Compression quality must be in the range 0.0 < quality <= 1.0");
                return 0;
            }
        }
        
        //load image
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:inputFile];        
        if (image)
        {
            //save as JPNG
            NSData *data = NSImageJPNGRepresentation(image, quality);
            if (!data)
            {
                NSLog(@"Failed to convert '%@' to JPNG", inputFile);
            }
            else if ([data writeToFile:outputFile atomically:YES])
            {
                NSLog(@"Converted '%@' to JPNG", inputFile);
            }
            else
            {
                NSLog(@"Failed to write JPNG to file '%@'", outputFile);
            }
        }
        else
        {
            NSLog(@"Failed to load '%@'", inputFile);
        }
    }
    return 0;
}

