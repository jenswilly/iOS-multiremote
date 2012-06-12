//
//  ButtonModel.h
//  Bluetooth LE
//
//  Created by Jens Willy Johannsen on 11-06-12.
//  Copyright (c) 2012 Greener Pastures. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TBXML.h"

typedef enum 
{
	ButtonModeTouchDown,
	ButtonModeTouchUp,
	ButtonModeRepeat
} ButtonMode;

@protocol ButtonModelDelegate <NSObject>

- (void)sendCommandAction:(id)sender;
- (void)repeatCommand:(UIButton*)sender;
- (void)cancelRepeatCommand:(id)sender;

@end

@interface ButtonModel : NSObject

@property (strong) NSString *text;
@property (strong) NSString *color;
@property (strong) UIImage *image;
@property NSUInteger number;
@property ButtonMode mode;

+ (ButtonModel*)buttonModelFromXMLNode:(TBXMLElement*)xmlNode;
- (UIButton*)buttonForDelegate:(id<ButtonModelDelegate>)delegate filenameFormat:(NSString*)filenameFormat;

@end
