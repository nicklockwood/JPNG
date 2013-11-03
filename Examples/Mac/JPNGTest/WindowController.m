//
//  WindowController.m
//  JPNGTest
//
//  Created by Nick Lockwood on 16/01/2013.
//  Copyright (c) 2013 Charcoal Design. All rights reserved.
//

#import "WindowController.h"

@implementation WindowController

- (void)awakeFromNib
{
    //image file
    NSString *fileName = @"Lake.jpng";
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"Lake" ofType:@"jpng"];
	NSData *imageData = [NSData dataWithContentsOfFile:filePath];
    
    //load images
    ((NSImageView *)[self.view viewWithTag:1]).image = [NSImage imageNamed:fileName];
    ((NSImageView *)[self.view viewWithTag:2]).image = [[NSImage alloc] initWithContentsOfFile:filePath];
    ((NSImageView *)[self.view viewWithTag:3]).image = [[NSImage alloc] initWithData:imageData];
}

@end
