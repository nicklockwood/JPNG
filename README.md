Purpose
--------------

In iOS and Mac OS apps there is typically a choice of two image formats: PNG format allows transparency but produces large image files and is unsuited to compressing images like photographs; JPEG is great for creating small files and provides a range of compression qualities to suit the subject matter, but doesn't allow for transparency.

JPNG is a new image format that combines the best of both of the other formats. JPNG is not really a format in its own right, it's a simple file wrapper that combines a JPEG and PNG image within the same file. JPEG is used to efficiently compress the RGB portion of the image and PNG is used to store the alpha channel.

The JPNG library provides functions for creating and loading files in the JPNG format on Mac or iOS. Included with the library is a simple command-line tool for converting PNG images to JPNG. By default, JPNG will also swizzle the UIImage and NSImage constructor methods so that they will load JPNG files automatically without requiring any additional code in your app. This swizzling can be disabled if you would prefer not to mess with the standard core library behaviour (see below for details).


Supported OS & SDK Versions
-----------------------------

* Supported build target - iOS 9.2 / Mac OS 10.11 (Xcode 7.2.1, Apple LLVM compiler 7.0)
* Earliest supported deployment target - iOS 7.0 / Mac OS 10.9
* Earliest compatible deployment target - iOS 4.3 / Mac OS 10.6 (64 bit)

NOTE: 'Supported' means that the library has been tested with this version. 'Compatible' means that the library should work on this OS version (i.e. it doesn't rely on any unavailable SDK features) but is no longer being tested for compatibility and may require tweaking or bug fixes to run correctly.


ARC Compatibility
------------------

JPNG requires ARC. If you wish to use JPNG in a non-ARC project, just add the -fobjc-arc compiler flag to the JPNG.m class. To do this, go to the Build Phases tab in your target settings, open the Compile Sources group, double-click JPNG.m in the list and type -fobjc-arc into the popover.

If you wish to convert your whole project to ARC, comment out the #error line in JPNG.m, then run the Edit > Refactor > Convert to Objective-C ARC... tool in Xcode and make sure all files that you wish to use ARC for (including JPNG.m) are checked.


Thread Safety
--------------

It is safe to load JPNG instances on a background thread, and to use them on a thread other than the one on which they were created. It is safe to call the methods reentrantly/concurrently on different threads.


Installation
---------------

To use JPNG, just drag the class files into your project and add the ImageIO framework in the Build Phases tab. JPNG will automatically extend UIImage or NSImage with the ability to load JPNG images without you needing to explicitly import the JPNG header into any of your classes, but if you have disabled swizzling, or wish to save images in JPNG format, just import the JPNG.h file to access these features.


Cross-platform functions
--------------------------

    CGImageRef CGImageCreateWithJPNGData(NSData *data, BOOL forceDecompression);
    
This method creates a CGImage object from JPNG encoded data. It is the responsibility of the caller to release this CGImage object using CGImageRelease(...). The forceDecompression argument determines if the image data should be decompressed in advance, or whether decompression can be deferred until later. It is advisable to set this argument to YES to improve drawing performance, unless you are planning to decompress the image yourself later by drawing it into a new CGContext.
    
    NSData *CGImageJPNGRepresentation(CGImageRef image, CGFloat quality);

This method returns an NSData representation of the supplied image. The NSData object that is returned is autoreleased. The supplied image must contain an alpha channel and the behaviour is undefined if it does not (that means it will probably crash). The quality value controls the JPEG compression level and should be in the range 0.0 to 1.0, with 1.0 being the highest possible quality.


UIKit functions
------------------

    UIImage *UIImageWithJPNGData(NSData *data, CGFloat scale, UIImageOrientation orientation);
    
This method returns a UIImage object created from JPNG encoded data. The UIImage object that is returned is autoreleased. The scale and orientation properties determine how it will be displayed. Supplying a value of zero for the scale means that the scale will match the main UIScreen scale.
    
    NSData *UIImageJPNGRepresentation(UIImage *image, CGFloat quality);

This method returns an NSData representation of the supplied image. The NSData object that is returned is autoreleased. The supplied image must contain an alpha channel and the behaviour is undefined if it does not (that means it will probably crash). The quality value controls the JPEG compression level and should be in the range 0.0 to 1.0, with 1.0 being the highest possible quality.


AppKit functions
------------------

    NSImage *NSImageWithJPNGData(NSData *data, CGFloat scale);
    
This method returns a NSImage object created from JPNG encoded data. The NSImage object that is returned is autoreleased. The scale property determines the size at which the NSImage will be displayed. Supplying a value of zero for the scale means that the scale will match the main NSScreen scale.
    
    NSData *NSImageJPNGRepresentation(NSImage *image, CGFloat quality);
    
This method returns an NSData representation of the supplied image. The NSData object that is returned is autoreleased. The supplied image must contain an alpha channel and the behaviour is undefined if it does not (that means it will probably crash). The quality value controls the JPEG compression level and should be in the range 0.0 to 1.0, with 1.0 being the highest possible quality.


Decompression
--------------

By default, iOS typically defers decompression of images until they are first drawn, and may discard the decompressed data when it is no longer needed. The only exception to this is if you load images using the [UIImage imageNamed:] method. This is good from a memory consumption standpoint, but reduces the performance of drawing images that are loaded using [UIImage imageWithContentsOfFile:], or equivalent.

JPNG attempts to emulate this behaviour as closely as possible, so JPNG images loaded using the UIImageWithJPNGData(...) and NSImageWithJPNGData(...) methods return compressed images by default, and the swizzled iOS and AppKit image loading methods behave the same as their native counterparts.

If you would prefer to force decompression for all images (to improve drawing performance at the expense of loading time and memory consumption), you can do so by adding the following pre-compiler macro to your build settings:

    JPNG_ALWAYS_FORCE_DECOMPRESSION=1

Or if you prefer, add this to your prefix.pch file:

    #define JPNG_ALWAYS_FORCE_DECOMPRESSION 1

To decide whether to decompress on a per-image basis, you can load images using the CGImageCreateWithJPNGData(...) function, which has an explicit forceDecompression argument.

If you aren't sure how the image will be loaded and want to code defensively, you can decompress a compressed JPNG by drawing it into a temporary image context, like this:

    UIImage *compressedJPNG = ...
    UIGraphicsBeginImageContextWithOptions(compressedJPNG.size, NO, image.compressedJPNG);
    [image drawAtPoint:CGPointZero];
    UIImage *uncompressedJPNG = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
The uncompressed image will then be optimized for drawing.
    

JPNGTool
--------------

JPNGTool is a command line application that can be used for converting images to JPNG format. Both the source and executable for this tool are included in the JPNGTool folder. JPNGTool accepts the following arguments:

    inputfile [outputfile] [quality]

- inputfile is the path to the image file that you wish to convert. This should ideally be a PNG image with alpha channel. No other formats have been tested currently and images without alpha may crash. This argument is required.
- outputfile is the path for the saved JPNG file. If this argument is omitted, it defaults to match the inputfile with a .jpng extension.
- quality is the JPEG compression quality for the RGB part of the image. This should be greater than 0.0 and less than or equal to 1.0, with 1.0 being the maximum quality. If this argument is omitted, it defaults to 0.8.

JPNGTool is designed to convert a single image at a time, however you can use the following commands to batch-convert a folder full of images:

    cd /Path/To/Image/Directory/
    find ./ -name \*.png | sed 's/\.png//g' | xargs -I % -n 1 /Path/To/JPNGTool %.png %.jpng 0.8


File Format
-----------------

The JPNG file format is very simple: It consists of a JPEG image data block, followed by a PNG image data block, followed by a footer that specifies the size of the image data blocks and some metatdata such as the file type and version. The reason the file is arranged like this - with a file footer instead of a header - is that it allows the file to appear as an ordinary JPEG to programs that are not JPNG-aware, allowing you to (for example) quickly preview the file contents using QuickLook on a Mac. The structure of the footer is as follows:


    typedef struct
    { 
        uint32_t imageSize;    //the total size in bytes of the JPEG image data
        uint32_t maskSize;     //the total size in bytes of the PNG mask data
        uint16_t footerSize;   //the total size in bytes of the JPNGFooter
        uint8_t majorVersion;  //the major file format version (major versions are incompatible)
        uint8_t minorVersion;  //the minor file format version (minor versions are compatible)
        uint32_t identifier;   //the 'JPNG' file identifier
    }
    JPNGFooter;
    

The last four bytes in the file always spell out 'JPNG', so you can use that fact to verify that a given data block contains a JPNG file as opposed to any other kind of image. This value is available in constant form:

    extern uint32_t JPNGIdentifier;


UIKit/AppKit swizzling
----------------------

By default, the JPNG library swizzles some UIImage and NSImage constructor methods so they can support JPNG files automatically. If you don't want this behaviour then don't panic, you can disable it by adding the following pre-compiler macro to your build settings:

    JPNG_SWIZZLE_ENABLED=0

Or if you prefer, add this to your prefix.pch file:

    #define JPNG_SWIZZLE_ENABLED 0

Before you do that though, be reassured that the swizzling that JPNG does is minimal and quite safe. It doesn't break UIImage or NSImage caching, or cause any other nasty side effects.

The swizzled methods in UIKit are as follows:

    [UIImage -initWithContentsOfFile:];
    [UIImage -initWithData:];
    [UIImage +imageNamed:];
    
And in AppKit:

    [NSImage -initWithContentsOfFile:];
    [NSImage -initWithData:];
    [NSImage +imageNamed:];
    
These methods are all swizzled for the same reason: to check if the image is a JPNG file. If it is, it will be loaded using the JPNG image loading functions, otherwise it is passed to the original methods to be loaded as normal.


GLKit support
---------------------

JPNG images can be used with OpenGL via GLKit, but there is no support for loading JPNG images directly from disk using GLKTextureLoader. Instead load the image using UIImage or NSImage (or any other method listed above), then get the CGImage representation and pass it to the GLKTextureLoader `+textureWithCGImage:options:error:` method (see the OpenGL example for details).

Note: OpenGL requires text image data to be provided in a particular format. By default, JPNG only returns the correct format if you load images using the [UIImage/NSImage imageNamed:] method, or using the CGImageCreateWithJPNGData(...) function with the forceDecompression argument set to YES. Images loaded using the other methods will not work correctly with GLKImageLoader unless the JPNG_ALWAYS_FORCE_DECOMPRESSION option is enabled.

If for some reason you need to load your JPNG in a different way, or you aren't sure how the image will be loaded and want to code defensively, you can convert a compressed JPNG to the correct format for GLKImageLoader by drawing it into a temporary image context, like this.

    UIImage *compressedJPNG = ...
    UIGraphicsBeginImageContextWithOptions(compressedJPNG.size, NO, image.compressedJPNG);
    [image drawAtPoint:CGPointZero];
    UIImage *uncompressedJPNG = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
The uncompressedJPNG image will now be safe to use with GLKImageLoader.
    

Benchmark
---------------------

The examples folder includes a benchmarking tool to compare PNG vs JPNG performance. To get an accurate result, ensure that you do the following:

1. Run on a device, not the simulator
2. Build in release mode, not debug
3. Disconnect from the debugger / Xcode
4. Kill the app and re-run a few times to verify


Release notes
--------------------

Version 1.2.2

- Fixed compiler errors / warnings on latest Xcode
- Added support for 3x Retina (iPhone 6 Plus)

Version 1.2.1

- Eliminated white border artefacts on the sides of transparent areas when creating the JPEG data
- JPNG now requires the ImageIO framework to be included on iOS

Version 1.2

- JPNG images are no longer decompressed automatically in most cases, bringing performance in line with ordinary PNGs (see README for details)
- Added forceDecompression option to CGImageCreateWithJPNGData()
- Added JPNG_ALWAYS_FORCE_DECOMPRESSION global setting
- Now complies with -Weverything warning level

Version 1.1.3

- Fixed memory leak when creating image
- Fixed color shift issue with JPNGTool
- Improved thread safety for +imageNamed: methods
- Now flushes image cache on iOS in the event of a low memory warning

Version 1.1.2

- Now supports stricter compiler warning settings
- JPNGTool now creates the output file directory if it doesn't already exist

Version 1.1.1

- JPNG images are now compatible with the GLKit texture loader
- Fixed a bug in the image file suffix handling logic
- Now complies with -Wextra warning level

Version 1.1

- Swizzling now works for all image loading methods on Mac and iOS
- Fixed error when not using StandardPaths
- Added test projects

Version 1.0

- Initial release
