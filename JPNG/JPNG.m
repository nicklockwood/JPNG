//
//  JPNG.m
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

#import "JPNG.h"
#import <objc/runtime.h>


#if !__has_feature(objc_arc)
#error This library requires automatic reference counting
#endif


//cross-platform implementation

uint32_t JPNGIdentifier = 'JPEG';

static void JPNG_swizzleInstanceMethod(Class c, SEL original, SEL replacement)
{
    Method a = class_getInstanceMethod(c, original);
    Method b = class_getInstanceMethod(c, replacement);
    if (class_addMethod(c, original, method_getImplementation(b), method_getTypeEncoding(b)))
    {
        class_replaceMethod(c, replacement, method_getImplementation(a), method_getTypeEncoding(a));
    }
    else
    {
        method_exchangeImplementations(a, b);
    }
}

CGImageRef CGImageCreateWithJPNGData(NSData *data)
{
    if ([data length] <= sizeof(JPNGFooter))
    {
        //not a JPNG
        return NULL;
    }
    
    JPNGFooter *footer = (JPNGFooter *)(data.bytes + [data length] - sizeof(JPNGFooter));
    if (footer->identifier != JPNGIdentifier)
    {
        //not a JPNG
        return NULL;
    }
    
    if (footer->majorVersion > 1)
    {
        //not compatible
        NSLog(@"This version of the JPNG library doesn't support JPNG version %i files", footer->majorVersion);
        return NULL;
    }
    
    //load image data
    NSRange range = NSMakeRange(0, footer->imageSize);
    CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((__bridge CFDataRef)[data subdataWithRange:range]);
    CGImageRef image = CGImageCreateWithJPEGDataProvider(dataProvider, NULL, true, kCGRenderingIntentDefault);
    CGDataProviderRelease(dataProvider);

    //load mask data
    range = NSMakeRange(footer->imageSize, footer->maskSize);
    dataProvider = CGDataProviderCreateWithCFData((__bridge CFDataRef)[data subdataWithRange:range]);
    CGImageRef mask = CGImageCreateWithPNGDataProvider(dataProvider, NULL, true, kCGRenderingIntentDefault);
    CGDataProviderRelease(dataProvider);

    //combine the two
    CGImageRef result = CGImageCreateWithMask(image, mask);
    CGImageRelease(image);
    CGImageRelease(mask);
    return result;
}

NSData *CGImageJPNGRepresentation(CGImageRef image, CGFloat quality)
{
    //split image and mask data
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    CFDataRef pixelData = CGDataProviderCopyData(CGImageGetDataProvider(image));
    uint8_t *colorData = (uint8_t *)CFDataGetBytePtr(pixelData);
    uint8_t *alphaData = malloc(width * height);
    for (int i = 0; i < height; i++)
    {
        for (int j = 0; j < width; j++)
        {
            size_t index = i * width + j;
            alphaData[index] = colorData[index * 4 + 3];
        }
    }
    CFRelease(pixelData);
    
    //get color image
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(colorData, width, height, 8, width * 4, colorSpace, kCGImageAlphaNoneSkipLast);
    image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
    
    //get image jpeg data
    UIImage *uiimage = [UIImage imageWithCGImage:image];
    CFDataRef imageData = (__bridge CFDataRef)UIImageJPEGRepresentation(uiimage, quality);
    CGImageRelease(image);
    
#else
    
    //get image jpeg data
    CFMutableDataRef imageData = CFDataCreateMutable(NULL, 0);
    CGImageDestinationRef destination = CGImageDestinationCreateWithData(imageData, kUTTypeJPEG, 1, NULL);
    NSDictionary *properties = @{(__bridge id)kCGImageDestinationLossyCompressionQuality: @(quality)};
    CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)properties);
    if (!CGImageDestinationFinalize(destination))
    {
        CFRelease(imageData);
        imageData = NULL;
    }
    CFRelease(destination);
    CGImageRelease(image);
    
#endif
    
    //get mask image
    colorSpace = CGColorSpaceCreateDeviceGray();
    context = CGBitmapContextCreate(alphaData, width, height, 8, width, colorSpace, 0);
    CGImageRef mask = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    free(alphaData);
    
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED

    //get mask png data
    UIImage *uimask = [UIImage imageWithCGImage:mask];
    CFDataRef maskData = (__bridge CFDataRef)UIImagePNGRepresentation(uimask);
    CGImageRelease(mask);
    
#else
    
    //get mask png data
    CFMutableDataRef maskData = CFDataCreateMutable(NULL, 0);
    destination = CGImageDestinationCreateWithData(maskData, kUTTypePNG, 1, NULL);
    CGImageDestinationAddImage(destination, mask, nil);
    if (!CGImageDestinationFinalize(destination))
    {
        CFRelease(maskData);
        maskData = NULL;
    }
    CFRelease(destination);
    CGImageRelease(mask);
    
#endif
 
    //check for success
    if (!imageData || !maskData)
    {
        if (imageData) CFRelease(imageData);
        if (maskData) CFRelease(maskData);
        return nil;
    }
   
    //create footer
    JPNGFooter footer =
    {
        (uint32_t)CFDataGetLength(imageData),
        (uint32_t)CFDataGetLength(maskData),
        (uint16_t)sizeof(JPNGFooter),
        1, 0, JPNGIdentifier
    };
    
    //create data
    NSMutableData *data = [NSMutableData dataWithLength:footer.imageSize + footer.maskSize + footer.footerSize];
    memcpy(data.mutableBytes, CFDataGetBytePtr(imageData), footer.imageSize);
    memcpy(data.mutableBytes + footer.imageSize, CFDataGetBytePtr(maskData), footer.maskSize);
    memcpy(data.mutableBytes + footer.imageSize + footer.maskSize, &footer, footer.footerSize);
    CFRelease(imageData);
    CFRelease(maskData);
    return data;
}


#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#import <UIKit/UIKit.h>


//iOS implementation

UIImage *UIImageWithJPNGData(NSData *data, CGFloat scale, UIImageOrientation orientation)
{
    CGImageRef imageRef = CGImageCreateWithJPNGData(data);
    return [UIImage imageWithCGImage:(__bridge CGImageRef)CFBridgingRelease(imageRef)
                               scale:scale
                         orientation:orientation];
}

NSData *UIImageJPNGRepresentation(UIImage *image, CGFloat quality)
{
    return CGImageJPNGRepresentation([image CGImage], quality);
}

#if JPNG_SWIZZLE_ENABLED

@implementation UIImage (JPNG)

+ (void)load
{
    JPNG_swizzleInstanceMethod(self, @selector(initWithData:), @selector(JPNG_initWithData:));
    JPNG_swizzleInstanceMethod(self, @selector(initWithContentsOfFile:), @selector(JPNG_initWithContentsOfFile:));
}

- (id)JPNG_initWithData:(NSData *)data
{
    CGImageRef imageRef = CGImageCreateWithJPNGData(data);
    if (imageRef)
    {
        return [self initWithCGImage:(__bridge CGImageRef)CFBridgingRelease(imageRef)];
    }
    return [self JPNG_initWithData:data];
}

- (id)JPNG_initWithContentsOfFile:(NSString *)file
{
    NSString *path = nil;
    CGFloat scale = 1.0f;
    
    if ([NSFileManager instancesRespondToSelector:@selector(normalizedPathForFile:)])
    {
        //StandardPaths library available
        path = [[NSFileManager defaultManager] normalizedPathForFile:file];
        scale = [path scaleFromSuffix];
    }
    else
    {
        //convert to absolute path
        path = file;
        if (![path isAbsolutePath])
        {
            path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:path];
        }
        
        //get path extension
        NSString *extension = [path pathExtension];
        if (![extension length]) extension = @"png";
        path = [path stringByDeletingPathExtension];
        
        //get device suffix
        NSString *deviceSuffix = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)? @"-iphone": @"-ipad";
        
        //generate suffixes
        NSArray *suffixes = @[ extension, [NSString stringWithFormat:@"%@%@", deviceSuffix, extension]];
        
        //check for Retina
        if ([UIScreen mainScreen].scale == 2.0f)
        {
            for (NSString *suffix in [suffixes objectEnumerator])
            {
                suffixes = [suffixes arrayByAddingObject:[@"2x" stringByAppendingString:suffix]];
            }
        }
     
        //try all suffixes
        for (NSString *suffix in [suffixes reverseObjectEnumerator])
        {
            NSString *_path = [path stringByAppendingPathSuffix:suffix];
            if ([[NSFileManager defaultManager] fileExistsAtPath:_path])
            {
                path = _path;
                break;
            }
        }
        
        //get scale from file suffix
        scale = ([path rangeOfString:@"@2x"].location != NSNotFound)? 2.0f: 1.0f;
    }
    
    //need to loading ourselves
    NSData *data = [NSData dataWithContentsOfFile:file];
    return [self initWithData:data scale:scale];
}

@end

#endif


#else
#import <AppKit/AppKit.h>


//Mac OS implementation

NSImage *NSImageWithJPNGData(NSData *data, CGFloat scale)
{
    CGImageRef imageRef = CGImageCreateWithJPNGData(data);
    if (imageRef)
    {
        scale = scale ?: [NSScreen mainScreen].backingScaleFactor;
        size_t width = CGImageGetWidth(imageRef);
        size_t height = CGImageGetHeight(imageRef);
        NSSize size = NSMakeSize(width * scale, height * scale);
        return [[NSImage alloc] initWithCGImage:(__bridge CGImageRef)CFBridgingRelease(imageRef) size:size];
    }
    return nil;
}

NSData *NSImageJPNGRepresentation(NSImage *image, CGFloat quality)
{
    NSSize size = [image size];
    NSArray *representations = [image representations];
    if ([representations count])
    {
        NSBitmapImageRep *representation = representations[0];
        size.width = [representation pixelsWide];
        size.height = [representation pixelsHigh];
    }
    NSRect rect = NSMakeRect(0.0f, 0.0f, size.width, size.height);
    CGImageRef imageRef = [image CGImageForProposedRect:&rect context:NULL hints:nil];
    return CGImageJPNGRepresentation(imageRef, quality);
}

#if JPNG_SWIZZLE_ENABLED

@implementation NSImage (JPNG)

+ (void)load
{
    JPNG_swizzleInstanceMethod(self, @selector(initWithData:), @selector(JPNG_initWithData:));
}

- (id)JPNG_initWithData:(NSData *)data
{
    CGImageRef imageRef = CGImageCreateWithJPNGData(data);
    if (imageRef)
    {
        NSSize size = NSMakeSize(CGImageGetWidth(imageRef), CGImageGetHeight(imageRef));
        return [self initWithCGImage:(__bridge CGImageRef)CFBridgingRelease(imageRef) size:size];
    }
    return [self JPNG_initWithData:data];
}

//TODO: check if any other image constructors need to be swizzled

@end

#endif


#endif