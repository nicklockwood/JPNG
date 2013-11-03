//
//  ViewController.m
//  JPNGTest
//
//  Created by Nick Lockwood on 16/01/2013.
//  Copyright (c) 2013 Charcoal Design. All rights reserved.
//

#import "ViewController.h"
#import "JPNG.h"


@interface ViewController ()

@property (nonatomic, strong) GLKBaseEffect *effect;

@end


@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.effect = [[GLKBaseEffect alloc] init];
    
    GLKView *view = (GLKView *)self.view;
    view.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:view.context];
    
    //load image file
    UIImage *image = [UIImage imageNamed:@"Lake.jpng"];
    
    //load texture
    NSError *error = nil;
    GLKTextureInfo *texture = [GLKTextureLoader textureWithCGImage:image.CGImage options:nil error:&error];
    if (texture)
    {
        self.effect.texture2d0.envMode = GLKTextureEnvModeReplace;
        self.effect.texture2d0.target = GLKTextureTarget2D;
        self.effect.texture2d0.name = texture.name;
    }
    else
    {
        NSLog(@"error: %@", error);
    }
}

- (void)update
{
    //bind shader program
    [self.effect prepareToDraw];
    
    //clear the screen
    glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(0.0, 0.0, 0.0, 1.0);
    
    //set up vertices
    GLKVector3 vertices[] =
    {
        GLKVector3Make(-0.5, -0.3, -1),
        GLKVector3Make(0.5, -0.3, -1),
        GLKVector3Make(0.5, 0.3, -1),
        GLKVector3Make(-0.5, 0.3, -1),
    };
    
    //set up textcoords
    GLKVector2 texcoords[] =
    {
        GLKVector2Make(0, 1),
        GLKVector2Make(1, 1),
        GLKVector2Make(1, 0),
        GLKVector2Make(0, 0),
    };
    
    //draw triangles
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, vertices);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 0, texcoords);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
}

@end
