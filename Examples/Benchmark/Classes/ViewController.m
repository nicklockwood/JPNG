//
//  ViewController.m
//
//  Created by Nick Lockwood on 03/02/2013.
//  Copyright (c) 2013 Charcoal Design. All rights reserved.
//

#import "ViewController.h"


@interface ViewController () <UITableViewDataSource>

@property (nonatomic, copy) NSArray *items;
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, strong) dispatch_queue_t queue;

@end


@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //set up image names
    self.items = @[@"1024x1024", @"512x512", @"256x256", @"128x128", @"64x64", @"32x32"];
}

- (CFTimeInterval)loadImageForOneSec:(NSString *)path
{
    //create drawing context to use for decompression
    UIGraphicsBeginImageContext(CGSizeMake(1, 1));
    
    //start timing
    NSInteger imagesLoaded = 0;
    CFTimeInterval endTime = 0;
    CFTimeInterval startTime = CFAbsoluteTimeGetCurrent();
    while (endTime - startTime < 1)
    {
        //load image
        UIImage *image = [UIImage imageWithContentsOfFile:path];
        
        //decompress image by drawing it
        [image drawAtPoint:CGPointZero];
        
        //update totals
        imagesLoaded ++;
        endTime = CFAbsoluteTimeGetCurrent();
    }
    
    //close context
    UIGraphicsEndImageContext();
    
    //calculate time per image
    return (endTime - startTime) / imagesLoaded;
}

- (void)loadImageAtIndex:(NSUInteger)index
{
    if (!_queue)
    {
        _queue = dispatch_queue_create("com.charcoaldesign.imageloading", NULL);
    }
    
    //load on background thread so as not to
    //prevent the UI from updating between runs
    dispatch_async(_queue, ^{
        
        //setup
        NSString *fileName = self.items[index];
        NSString *pngPath = [[NSBundle mainBundle] pathForResource:fileName ofType:@"png"];
        NSString *jpngPath = [[NSBundle mainBundle] pathForResource:fileName ofType:@"jpng"];

        //load
        NSInteger pngTime = [self loadImageForOneSec:pngPath] * 1000;
        NSInteger jpngTime = [self loadImageForOneSec:jpngPath] * 1000;
        
        //updated UI on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            
            //find table cell and update
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"PNG: %@ms  JPNG: %@ms",
                                         @(pngTime), @(jpngTime)];
        });
    });
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    return [self.items count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //dequeue cell
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell"];
    
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:@"Cell"];
    }
    
    //set up cell
    NSString *imageName = self.items[indexPath.row];
    cell.textLabel.text = imageName;
    cell.detailTextLabel.text = @"Loading...";
    
    //load image
    [self loadImageAtIndex:indexPath.row];

    return cell;
}

@end
