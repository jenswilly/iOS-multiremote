//
//  ButtonModel.m
//  Bluetooth LE
//
//  Created by Jens Willy Johannsen on 11-06-12.
//  Copyright (c) 2012 Greener Pastures. All rights reserved.
//

#import "ButtonModel.h"
#import <QuartzCore/QuartzCore.h>

@implementation ButtonModel
@synthesize text, color, image, number, mode;

+ (ButtonModel*)buttonModelFromXMLNode:(TBXMLElement*)xmlNode
{
	ButtonModel *button = [[ButtonModel alloc] init];
	
	// Extract values from XML node
	button.color = [TBXML valueOfAttributeNamed:@"color" forElement:xmlNode];
	button.text = [TBXML valueOfAttributeNamed:@"text" forElement:xmlNode];
	button.number = [[TBXML valueOfAttributeNamed:@"id" forElement:xmlNode] intValue];
	
	// Load image if specified
	NSString *imageName = [TBXML valueOfAttributeNamed:@"image" forElement:xmlNode];
	if( [imageName length] > 0 )
		button.image = [UIImage imageNamed:imageName];

	// Set button mode
	NSString *modeString = [[TBXML valueOfAttributeNamed:@"mode" forElement:xmlNode] lowercaseString];
	if( [[modeString lowercaseString] isEqualToString:@"touchdown"] )
		button.mode = ButtonModeTouchDown;
	else if( [[modeString lowercaseString] isEqualToString:@"repeat"] )
		button.mode = ButtonModeRepeat;
	else // Otherwise, we'll assume TouchUp
		button.mode = ButtonModeTouchUp;
	
	return button;
}

- (UIButton*)buttonForDelegate:(id<ButtonModelDelegate>)delegate filenameFormat:(NSString*)filenameFormat
{
	// Make sure we have color and either text or image
	if( [self.color length] == 0 || ([self.text length] == 0 && self.image == nil) )
	{
		// We need color and either text or image: return nil
		return nil;
	}

	// Create and configure button
	UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *img = [UIImage imageNamed:[NSString stringWithFormat:filenameFormat, self.color]];
	[btn setBackgroundImage:img forState:UIControlStateNormal];
	btn.frame = CGRectMake( 0, 0, img.size.width, img.size.height );
	
	// Do we have text?
	if( [self.text length] > 0 )
	{
		// Yes: configure label
		[btn setTitle:self.text forState:UIControlStateNormal];
		[btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		[btn setTitleColor:[UIColor grayColor] forState:UIControlStateDisabled];
		[btn setTitleShadowColor:[UIColor blackColor] forState:UIControlStateNormal];
		[btn setTitleShadowColor:[UIColor clearColor] forState:UIControlStateDisabled];
		btn.titleLabel.shadowOffset = CGSizeMake( 0, -1 );
		btn.titleLabel.font = [UIFont boldSystemFontOfSize:( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 30 : 15 )];
	}
	else 
	{
		// Otherwise we must have an image: set image
		[btn setImage:self.image forState:UIControlStateNormal];
	}
	
	// Set tag to command index
	btn.tag = self.number;
	if( self.mode == ButtonModeTouchDown )
		[btn addTarget:delegate action:@selector(sendCommandAction:) forControlEvents:UIControlEventTouchDown];
	else if( self.mode == ButtonModeRepeat )
	{
		[btn addTarget:delegate action:@selector(repeatCommand:) forControlEvents:UIControlEventTouchDown];
		[btn addTarget:delegate action:@selector(cancelRepeatCommand:) forControlEvents:UIControlEventTouchUpInside];
		[btn addTarget:delegate action:@selector(cancelRepeatCommand:) forControlEvents:UIControlEventTouchUpOutside];
	}
	else	// TouchUp
		[btn addTarget:delegate action:@selector(sendCommandAction:) forControlEvents:UIControlEventTouchUpInside];
	
	// Configure shadow. The shadow opacity is initially set to 0 but will be shown then learning.
	btn.layer.shadowColor = [UIColor redColor].CGColor;
	btn.layer.shadowRadius = 20.0f;
	btn.layer.shadowOffset = CGSizeZero;

	return btn;
}

@end
