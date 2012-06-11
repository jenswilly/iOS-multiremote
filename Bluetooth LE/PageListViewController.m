//
//  PageListViewController.m
//  Bluetooth LE
//
//  Created by Jens Willy Johannsen on 07-06-12.
//  Copyright (c) 2012 Greener Pastures. All rights reserved.
//

#import "PageListViewController.h"
#import "MainViewController.h"
#import "AppDelegate.h"

@interface PageListViewController ()

@end

@implementation PageListViewController
@synthesize detailViewController;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	// Set (weak) reference to detail view controller
	self.detailViewController = [APP mainViewController];
	detailViewController.masterViewController = self;
	
	 // Set background pattern
	self.tableView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"metal_pattern2.png"]];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [detailViewController.pages count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"deviceCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    // Configure the cell...
    cell.textLabel.text = [detailViewController.pages objectAtIndex:indexPath.row];
	
	if( indexPath.row == 1 )
		cell.imageView.image = [UIImage imageNamed:@"orb_green.png"];
	else 
		cell.imageView.image = [UIImage imageNamed:@"orb_gray.png"];
	
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.detailViewController toggleDebugAction:nil];
}

@end
