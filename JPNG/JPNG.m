//
//  JPNG.m
//
//  Version 1.1.3
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
#import <objc/message.h>


#if !__has_feature(objc_arc)
#error This library requires automatic reference counting
#endif


//cross-platform implementation

uint32_t JPNGIdentifier = 'JPEG';

CGImageRef CGImageCreateWithJPNGData(NSData *data)
{
    if ([data length] <= sizeof(JPNGFooter))
    {
        //not a JPNG
        return NULL;
    }
    
    JPNGFooter footer;
    memcpy(&footer, (uint8_t *)data.bytes + [data length] - sizeof(JPNGFooter), sizeof(JPNGFooter));
    if (footer.identifier != JPNGIdentifier)
    {
        //not a JPNG
        return NULL;
    }
    
    if (footer.majorVersion > 1)
    {
        //not compatible
        NSLog(@"This version of the JPNG library doesn't support JPNG version %i files", footer.majorVersion);
        return NULL;
    }
    
    //load image data
    NSRange range = NSMakeRange(0, footer.imageSize);
    CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((__bridge CFDataRef)[data subdataWithRange:range]);
    CGImageRef image = CGImageCreateWithJPEGDataProvider(dataProvider, NULL, true, kCGRenderingIntentDefault);
    CGDataProviderRelease(dataProvider);
    
    //load mask data
    range = NSMakeRange(footer.imageSize, footer.maskSize);
    dataProvider = CGDataProviderCreateWithCFData((__bridge CFDataRef)[data subdataWithRange:range]);
    CGImageRef mask = CGImageCreateWithPNGDataProvider(dataProvider, NULL, true, kCGRenderingIntentDefault);
    CGDataProviderRelease(dataProvider);
    
    //create output context
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image);
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)(kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4, colorSpace, bitmapInfo);
    CGRect rect = CGRectMake(0.0f, 0.0f, width, height);
    CGContextClipToMask(context, rect, mask);
    CGContextDrawImage(context, rect, image);
    CGImageRef result = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
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
    uint8_t *alphaData = (uint8_t *)malloc(width * height);
    for (size_t i = 0; i < height; i++)
    {
        for (size_t j = 0; j < width; j++)
        {
            size_t index = i * width + j;
            alphaData[index] = colorData[index * 4 + 3];
        }
    }
    CFRelease(pixelData);
    
    //get color image
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image);
    CGBitmapInfo byteOrder = CGImageGetBitmapInfo(image) & kCGBitmapByteOrderMask;
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)(kCGImageAlphaPremultipliedLast | byteOrder);
    CGContextRef context = CGBitmapContextCreate(colorData, width, height, 8, width * 4, colorSpace, bitmapInfo);
    image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    
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
    context = CGBitmapContextCreate(alphaData, width, height, 8, width, colorSpace, (CGBitmapInfo)0);
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
    memcpy((uint8_t *)data.mutableBytes + footer.imageSize, CFDataGetBytePtr(maskData), footer.maskSize);
    memcpy((uint8_t *)data.mutableBytes + footer.imageSize + footer.maskSize, &footer, footer.footerSize);
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


#endif


#if JPNG_SWIZZLE_ENABLED

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

static void JPNG_swizzleClassMethod(Class c, SEL original, SEL replacement)
{
    Method a = class_getClassMethod(c, original);
    Method b = class_getClassMethod(c, replacement);
    method_exchangeImplementations(a, b);
}

void JPNG_getNormalizedFile(NSString **path, CGFloat *scale)
{
    SEL normalizedPathSelector = NSSelectorFromString(@"normalizedPathForFile:");
    if ([NSFileManager instancesRespondToSelector:normalizedPathSelector])
    {
        //StandardPaths library available
        *path = ((id (*)(id, SEL, id))objc_msgSend)([NSFileManager defaultManager], normalizedPathSelector, *path);
        *scale = [[*path valueForKey:@"scaleFromSuffix"] floatValue];
    }
    else
    {
        //get path extension
        NSString *extension = [*path pathExtension];
        if (![extension length]) extension = @"png";
        *path = [*path stringByDeletingPathExtension];
        
        //generate suffixes
        NSArray *suffixes = @[[@"." stringByAppendingString:extension]];
        
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
        
        //get device suffix
        NSString *deviceSuffix = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)? @"~iphone": @"~ipad";
        
        //add device suffix
        suffixes = [suffixes arrayByAddingObject:[NSString stringWithFormat:@"%@.%@", deviceSuffix, extension]];
        
        //get screen scale
        CGFloat deviceScale = [UIScreen mainScreen].scale;
        
#else
        
        //get screen scale
        CGFloat deviceScale = 1.0f;
        if ([NSScreen instancesRespondToSelector:@selector(backingScaleFactor)])
        {
            deviceScale = [[NSScreen mainScreen] backingScaleFactor];
        }
        
#endif
        
        //check for Retina version
        if (deviceScale == 2.0f)
        {
            for (NSString *suffix in [suffixes objectEnumerator])
            {
                suffixes = [suffixes arrayByAddingObject:[@"@2x" stringByAppendingString:suffix]];
            }
        }
        
        //try all suffixes
        for (NSString *suffix in [suffixes reverseObjectEnumerator])
        {
            NSString *_path = [*path stringByAppendingString:suffix];
            if ([[NSFileManager defaultManager] fileExistsAtPath:_path])
            {
                *path = _path;
                break;
            }
        }
        
        //get scale from file suffix
        *scale = ([*path rangeOfString:@"@2x"].location != NSNotFound)? 2.0f: 1.0f;
    }
}


#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED


@implementation UIImage (JPNG)

+ (void)load
{
    JPNG_swizzleInstanceMethod(self, @selector(initWithData:), @selector(JPNG_initWithData:));
    JPNG_swizzleInstanceMethod(self, @selector(initWithContentsOfFile:), @selector(JPNG_initWithContentsOfFile:));
    JPNG_swizzleClassMethod(self, @selector(imageNamed:), @selector(JPNG_imageNamed:));
}

+ (NSCache *)JPNG_imageCache
{
    static NSCache *cache = nil;
    if (cache == nil)
    {
        cache = [[NSCache alloc] init];
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *note) {
            
            [cache removeAllObjects];
        }];
    }
    return cache;
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
    NSString *path = file;
    CGFloat scale = 1.0f;
    
    //emulate Apple's file suffix detection
    JPNG_getNormalizedFile(&path, &scale);
    
    //need to handle loading ourselves
    NSData *data = [NSData dataWithContentsOfFile:path];
    return [self initWithData:data scale:scale];
}

+ (id)JPNG_imageNamed:(NSString *)name
{
    //only check file extension - too expensive to check file footer
    if ([[[name pathExtension] lowercaseString] isEqualToString:@"jpng"])
    {
        //convert to absolute path
        NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:name];
        
        @synchronized ([self class])
        {
            //need to handle loading & caching ourselves
            NSCache *cache = [self JPNG_imageCache];
            UIImage *image = [cache objectForKey:name];
            if (!image)
            {
                image = [UIImage imageWithContentsOfFile:path];
                if (image) [cache setObject:image forKey:name];
            }
            return image;
        }
    }
    else
    {
        return [UIImage JPNG_imageNamed:name];
    }
}

@end


#else


@implementation NSImage (JPNG)

+ (void)load
{
    JPNG_swizzleInstanceMethod(self, @selector(initWithData:), @selector(JPNG_initWithData:));
    JPNG_swizzleInstanceMethod(self, @selector(initWithContentsOfFile:), @selector(JPNG_initWithContentsOfFile:));
    JPNG_swizzleClassMethod(self, @selector(imageNamed:), @selector(JPNG_imageNamed:));
}

+ (NSCache *)JPNG_imageCache
{
    static NSCache *cache = nil;
    if (cache == nil)
    {
        cache = [[NSCache alloc] init];
    }
    return cache;
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

- (id)JPNG_initWithContentsOfFile:(NSString *)file
{
    NSString *path = file;
    CGFloat scale = 1.0f;
    
    //emulate Apple's file suffix detection
    JPNG_getNormalizedFile(&path, &scale);
    
    //need to handle loading ourselves
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSImage *image = [self initWithData:data];
    if (image)
    {
        image.size = NSMakeSize(image.size.width / scale, image.size.height / scale);
    }
    return image;
}

+ (id)JPNG_imageNamed:(NSString *)name
{
    //only check file extension - too expensive to check file footer
    if ([[[name pathExtension] lowercaseString] isEqualToString:@"jpng"])
    {
        //convert to absolute path
        NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:name];
        
        @synchronized ([self class])
        {
            //need to handle loading & caching ourselves
            NSCache *cache = [self JPNG_imageCache];
            NSImage *image = [cache objectForKey:name];
            if (!image)
            {
                image = [[NSImage alloc] initWithContentsOfFile:path];
                if (image) [cache setObject:image forKey:name];
            }
            return image;
        }
    }
    else
    {
        return [NSImage JPNG_imageNamed:name];
    }
}

@end


#endif

#endif