Purpose
--------------

In iOS and Mac OS apps there is typically a choice of two image formats: PNG format allows transparency but produces large image files and is unsuited to compressing images like photographs; JPEG is great for creating small files and provides a range of compression qualities to suit the subject matter, but doesn't allow for transparency.

JPNG is a new image format that combines the best of both of the other formats. JPNG is not really a format in its own right, it's a simple file wrapper that combines a JPEG and PNG image within the same file. JPEG is used to efficiently compress the RGB portion of the image and PNG is used to store the alpha channel.

The JPNG library provides functions for creating and loading files in the JPNG format on Mac or iOS. Included with the library is a simple command-line tool for converting PNG images to JPNG. By default, JPNG will also swizzle the UIImage and NSImage constructor methods so that they will load JPNG files automatically without requiring any additional code in your app. This swizzling can be disabled if you would prefer not to mess with the standard core library behaviour (see below for details).


Supported OS & SDK Versions
-----------------------------

* Supported build target - iOS 6.0 / Mac OS 10.8 (Xcode 4.5, Apple LLVM compiler 4.1)
* Earliest supported deployment target - iOS 5.0 / Mac OS 10.7
* Earliest compatible deployment target - iOS 4.3 / Mac OS 10.6 (64 bit)

NOTE: 'Supported' means that the library has been tested with this version. 'Compatible' means that the library should work on this OS version (i.e. it doesn't rely on any unavailable SDK features) but is no longer being tested for compatibility and may require tweaking or bug fixes to run correctly.


ARC Compatibility
------------------

JPNG requires ARC. If you wish to use JPNG in a non-ARC project, just add the -fobjc-arc compiler flag to the JPNG.m class. To do this, go to the Build Phases tab in your target settings, open the Compile Sources group, double-click JPNG.m in the list and type -fobjc-arc into the popover.

If you wish to convert your whole project to ARC, comment out the #error line in JPNG.m, then run the Edit > Refactor > Convert to Objective-C ARC... tool in Xcode and make sure all files that you wish to use ARC for (including JPNG.m) are checked.


Installation
---------------

To use JPNG, just drag the class files into your project. JPNG will automatically extend UIImage or NSImage with the ability to load JPNG images without you needing to explictly import the JPNG header into any of your classes, but if you have disabled swizzling, or wish to save images in JPNG format, just import the JPNG.h file to access these features.


Cross-platform functions
--------------------------

    CGImageRef CGImageCreateWithJPNGData(NSData *data);
    
This method creates a CGImage object from JPNG encoded data. It is the responsibility of the caller to release this CGImage object using CGImageRelease();
    
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


JPNGTool
--------------

JPNGTool is a command line application that can be used for converting images to JPNG format. Both the source and executable for this tool are included in the JPNGTool folder. JPNGTool accepts the following arguments:

    inputfile [outputfile] [quality]

- inputfile is the path to the image file that you wisht to convert. This should ideally be a PNG image with alpha channel. No other formats have been tested currently and images without alpha may crash. This argument is required.
- outputfile is the path for the saved JPNG file. If this argument is omitted, it defaults to match the inputfile with a .jpng extension.
- quality is the JPEG compression quality for the RGB part of the image. This should be greater than 0.0 and less than or equal to 1.0, with 1.0 being the maximum quality. If this argument is omitted, it defaults to 0.8.

JPNGTool is designed to convert a single image at a time, however you can use the following command to batch-convert a folder full of images:

    find /Path/To/Image/Directory/ -name \*.png | sed 's/\.png//g' | xargs -I % -n 1  /Path/To/JPNGTool %.png %.jpng 0.8


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

Before you do that though, be reassured that the swizzling that JPNG does is minimal and quite safe. It doesn't break UIImage caching, or cause any other nasty side effects like some solutions out there.

The swizzled methods in UIKit are as follows:

    [UIImage initWithContentsOfFile:];
    [UIImage initWithData:];
    
And in AppKit:

    [NSImage initWithData:];
    
These methods are all swizzled for the same reason: to check if the image data has the JPNG footer. If it does, it will be loaded using the JPNG image loading functions, otherwise it is passed to the original init methods to be loaded as normal.