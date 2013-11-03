//
//  ViewController.m
//  JPNGTest
//
//  Created by Nick Lockwood on 16/01/2013.
//  Copyright (c) 2013 Charcoal Design. All rights reserved.
//

#import "ViewController.h"


@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //image file
    NSString *fileName = @"Lake.jpng";
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"Lake" ofType:@"jpng"];
	NSData *imageData = [NSData dataWithContentsOfFile:filePath];
    
    //load images
    ((UIImageView *)[self.view viewWithTag:1]).image = [UIImage imageNamed:fileName];
    ((UIImageView *)[self.view viewWithTag:2]).image = [UIImage imageWithContentsOfFile:filePath];
    ((UIImageView *)[self.view viewWithTag:3]).image = [[UIImage alloc] initWithData:imageData];
}

@end
