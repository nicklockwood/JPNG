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