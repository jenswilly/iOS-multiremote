//
//  PageCell.m
//  Bluetooth LE
//
//  Created by Jens Willy Johannsen on 09-06-12.
//  Copyright (c) 2012 Greener Pastures. All rights reserved.
//

#import "PageCell.h"

@implementation PageCell

- (void)awakeFromNib
{
	DEBUG_POSITION;
	self.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"cell_bg.png"]];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
