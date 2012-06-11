//
//  PageListViewController.h
//  Bluetooth LE
//
//  Created by Jens Willy Johannsen on 07-06-12.
//  Copyright (c) 2012 Greener Pastures. All rights reserved.
//

#import <UIKit/UIKit.h>
@class MainViewController;

@interface PageListViewController : UITableViewController

@property (weak) MainViewController *detailViewController;

@end
