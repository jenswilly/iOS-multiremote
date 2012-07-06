//
//  ViewController.m
//  Bluetooth LE
//
//  Created by Jens Willy Johannsen on 30-04-12.
//  Copyright (c) 2012 Greener Pastures. All rights reserved.
//

#import "MainViewController.h"
#import "CBUUID+Utils.h"
#import "MBProgressHUD.h"
#import "TBXML.h"
#import "PageListViewController.h"
#import "ButtonModel.h"

#define UUID_GCAC_SERVICE @"b8b96269-562a-408f-8155-0b45f21c7774"
#define UUID_DEVICE_INFORMATION @"180a"
#define UUID_COMMAND_CHARATERISTIC @"bf33aeaf-8653-4841-89c8-330fa4f13346"
#define UUID_RESPONSE_CHARACTERISTIC @"51494780-28c9-4502-87f1-c23881c70300"

#define COMMAND_NUMBER @"commandNumber"

#define SCAN_TIMEOUT 2.0f	// Timeout value for scanning

// Anonymous enum with tags
enum 
{
	TagConnectToDeviceActionSheet,
	TagJumpToPageActionSheet
} Tags;

// Coordinates for buttons
static const CGFloat xCoords[] = {24, 117, 210};
static const CGFloat yCoords[] = {7, 101, 195, 289};

@implementation MainViewController
@synthesize contentView = _contentView;
@synthesize centralManager, peripherals, connectedPeripheral, GCACService, GCACCommandCharacteristic, GCACResponseCharacteristic, peripheralNames, pages, pageContent, masterViewController, currentButtonsView = _currentButtonsView, currentPageName;
@synthesize learnButton = _learnButton;
@synthesize debugButton = _debugButton;
@synthesize connectButton = _connectButton;
@synthesize flexSpace = _flexSpace;
@synthesize toolbar = _toolbar;
@synthesize pageLabelScroller = _pageLabelScroller;
@synthesize textView = _textView;
@synthesize debugView = _debugView;
@synthesize mainScroller = _mainScroller;
@synthesize popover = _popover;

- (void)viewDidLoad
{
    [super viewDidLoad];

	DEBUG_POSITION;
	
	// Set background for iPad
	// iPhone or iPad?
	if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
		self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"metal_pattern.png"]];

	// Power up Bluetooth LE central manager (main queue)
	centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
	// Wait for callback to report BTLE ready.
	
	// Initialize
	peripherals = [[NSMutableArray alloc] init];
	peripheralNames = [[NSMutableDictionary alloc] init];	
	
	// Load sound
	NSError *error = nil;
	audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"tock" ofType:@"aif"]] error:&error];
	NSAssert( error == nil, @"Error loading sound: %@", [error localizedDescription] );
    [audioPlayer prepareToPlay];
	
	// Set toolbar items
	_learnButton.enabled = NO;
	 
	// Load xml
	// iPhone or iPad?
	/// BUG: this shouldn't be necessary – maybe iOS 6 doesn't support ~iPad postfix for iPad files yet?
	if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
		[self parseXMLFile:@"remote~iPad.xml"];
	else
		[self parseXMLFile:@"remote.xml"];

	// Disable all buttons requiring a connection
	[self disableButtons];
	
	// Setup shadow properties for the toolbar
	_toolbar.layer.shadowColor = [UIColor redColor].CGColor;
	_toolbar.layer.shadowRadius = 40;
	_toolbar.layer.shadowOffset = CGSizeMake( 0, 22 );
	_toolbar.layer.shadowOpacity = 0.0f;
	
	commandMode = CommandModeIdle;
}

- (void)viewDidUnload
{
	[self setTextView:nil];
    [self setDebugView:nil];
	[self setLearnButton:nil];
	[self setDebugButton:nil];
	[self setConnectButton:nil];
	[self setMainScroller:nil];
	[self setFlexSpace:nil];
	[self setToolbar:nil];
	[self setPageLabelScroller:nil];
	[self setContentView:nil];
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	// iPhone or iPad?
	if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
		// All orientations supported for iPad
		return YES;
	else
		// iPhone supports only portrait orientations
		return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - UIScrollViewDelegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	// Calculate position for title scroller: one page in the main scroller corresponds to 80px in the title scroller
	CGFloat titleScrollerOffset = -160 + _mainScroller.contentOffset.x / 320 * 80;
	_pageLabelScroller.contentOffset = CGPointMake( titleScrollerOffset, 0 );
}

#pragma mark - Private methods

- (void)populateTitleLabelScroller:(NSArray*)pageTitles{
	CGFloat xPos = 0;
	CGFloat maxX = 0;
	
	for( NSString *pageTitle in pageTitles )
	{
		// Create label
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
		label.backgroundColor = [UIColor clearColor];
		label.font = [UIFont boldSystemFontOfSize:[UIFont systemFontSize]];
		label.textColor = [UIColor whiteColor];
		label.shadowColor = [UIColor blackColor];
		label.shadowOffset = CGSizeMake( 0, 1 );
		label.text = pageTitle;
		[label sizeToFit];
		
		// Position
		CGRect frame = label.frame;
		frame.origin.x = xPos - frame.size.width/2;
		frame.origin.y = _pageLabelScroller.bounds.size.height/2 - frame.size.height/2;
		label.frame = frame;
		xPos += 80;
		maxX = CGRectGetMaxX( label.frame );
		
		[_pageLabelScroller addSubview:label];
	}
	
	// Initial position
	_pageLabelScroller.contentSize = CGSizeMake( maxX, _pageLabelScroller.bounds.size.height );
	_pageLabelScroller.contentOffset = CGPointMake( -160, 0 );
}

- (void)print:(NSString *)text
{
	NSMutableString *debugString = [text mutableCopy];
	if( ![NSThread currentThread].isMainThread )
		[debugString appendString:@" [THREAD!]"];
		 
	DEBUG_LOG( @"--> %@", debugString );
#if DEBUG
	_textView.text = [_textView.text stringByAppendingFormat:@"\r%@", debugString];
	[_textView scrollRangeToVisible:NSMakeRange( [_textView.text length]-1, 1 )];
#endif
}

- (void)scanTimeout:(NSTimer*)timer
{
	// Stop scanning
	[centralManager stopScan];
	[MBProgressHUD hideHUDForView:self.view animated:YES];
	[self print:@"Done scanning."];
	
	// We're done scanning for devices. If we're not yet connecting, let the user pick a device if we found any
	if( [peripherals count] > 0 )
	{
		// We found some: show action sheet
		
		/// BUG: iOS 6 fix
		UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Connect to device" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Device", nil];
		actionSheet.tag = TagConnectToDeviceActionSheet;
		
		/// BUG: iOS 6 – can't add buttons in iOS 6. Or is it iPad? :(
		/*
		UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Connect to device" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Thing", nil];
		
		// Iterate devices
		for( CBPeripheral *peripheral in peripherals )
		{
			// Do we have a name for the device?
			if( [peripheralNames objectForKey:[CBUUID stringFromCFUUIDRef:peripheral.UUID]] )
				// Yes: use the name
				[actionSheet addButtonWithTitle:[peripheralNames objectForKey:[CBUUID stringFromCFUUIDRef:peripheral.UUID]]];
			else 
				// No: use UUID
				[actionSheet addButtonWithTitle:[CBUUID stringFromCFUUIDRef:peripheral.UUID]];
		}
		 */
		[actionSheet showInView:self.view];
	}
	else 
	{
		[self print:@"... no devices found."];
		
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No devices found" message:@"Make sure the device is switched on and in range." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
		[alert show];
		
		// Set last item of the toolbar to the scan button (enabled)
		_learnButton.enabled = NO;
		_connectButton.enabled = YES;
		_connectButton.image = [UIImage imageNamed:@"barbtn_lightning"];
	}
}

- (void)sendCommand:(NSUInteger)commandNumber
{
	if( self.connectedPeripheral == nil )
	{
		[self print:@"Not connected."];
		return;
	}
	
	// Build command string
	NSString *commandPrefix = (learning ? @"L" : @"S");
	NSString *commandString = [NSString stringWithFormat:@"%@-%03d", commandPrefix, commandNumber];
	[self print:[NSString stringWithFormat:@"Sending \"%@", commandString]];
	[connectedPeripheral writeValue:[commandString dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:GCACCommandCharacteristic type:CBCharacteristicWriteWithResponse];
	
	// Not learning anymore
	if( learning )
	{
		learning = NO;
		[self showLearningAnimation:learning];
	}
}

#pragma mark - UIActionSheetDelegate methods

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	// Was it the "Jump to page" action sheet?
	if( actionSheet.tag == TagJumpToPageActionSheet )
	{
		// Cancel?
		if( buttonIndex == actionSheet.cancelButtonIndex )
			// Yes: just return
			return;
		
		// Otherwise jump to page. Index corresponds page number, 1-based
		[_mainScroller setContentOffset:CGPointMake( _mainScroller.bounds.size.width * (buttonIndex-1), 0) animated:YES];
	}
	
	// Connect to device action sheet
	if( actionSheet.tag == TagConnectToDeviceActionSheet )
	{
		// Was it cancel?
		if( buttonIndex == actionSheet.cancelButtonIndex )
		{
			// Yes: enable scan button and exit
			_connectButton.enabled = YES;
			return;
		}
		
		// Otherwise, connect to specified device
		CBPeripheral *peripheral;
		
		// iPhone or iPad?
		if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
		{
			peripheral = [peripherals objectAtIndex:0];
		}
		else
		{
			peripheral = [peripherals objectAtIndex:buttonIndex - 1];	// -1 for the Cancel button
		}
		
		DEBUG_LOG( @"Peripheral: %@", [peripheral description] );

		[MBProgressHUD showHUDAddedTo:self.view animated:YES];
		[centralManager connectPeripheral:peripheral options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
	}
}

#pragma mark - CBCentralManagerDelegate methods

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
	switch( central.state )
	{
        case CBCentralManagerStateUnknown: 
        case CBCentralManagerStateResetting:
			break;

        case CBCentralManagerStateUnsupported:
			[self print:@"Core Bluetooth not supported on this device."];
			break;

        case CBCentralManagerStateUnauthorized:
			[self print:@"Core Bluetooth not authorized."];
			break;
			
        case CBCentralManagerStatePoweredOff:
			[self print:@"Core Bluetooth powered off."];
			break;
			
        case CBCentralManagerStatePoweredOn:
			[self print:@"Core Bluetooth ready."];
			// Start scanning if not connected
			[self performSelector:@selector(scanAction:) withObject:nil afterDelay:0.3f];
			break;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
	// Perepheral discovered: add it
	[peripherals addObject:peripheral];
	
	[self print:[NSString stringWithFormat:@"Found peripheral with UUID %@, advertisement %@", [CBUUID stringFromCFUUIDRef:peripheral.UUID], [advertisementData description]]];
	
	// Is it the preferred device?
	CBUUID *uuid = [CBUUID UUIDWithCFUUID:peripheral.UUID];
	if( [uuid isEqualToUUID:APP.preferredDeviceUUID] )
	{
		// Yes: stop scanning and connect immediately
		[self print:@"Found preferred device – connecting..." ];
		[centralManager stopScan];
		[scanTimer invalidate];	// So we don't get to the "done scanning" method
		
		// Connect...
		[centralManager connectPeripheral:peripheral options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
	}
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
	// Hide HUD
	[MBProgressHUD hideHUDForView:self.view animated:YES];
	
	[self print:[NSString stringWithFormat:@"Connected to peripheral: %@", [CBUUID stringFromCFUUIDRef:peripheral.UUID]]];
	
	// Set property and remember as preferred device
	peripheral.delegate = self;
	self.connectedPeripheral = peripheral; 
	APP.preferredDeviceUUID = [CBUUID UUIDWithCFUUID:peripheral.UUID];
	
	// Find the GCAC service
	[peripheral discoverServices:[NSArray arrayWithObject:[CBUUID UUIDWithString:UUID_GCAC_SERVICE]]];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
	// Check for error
	if( error != nil )
	{
		// Error
		[self print:[NSString stringWithFormat:@"Error disconnecting peripheral: %@", [error localizedDescription]]];
		return;
	}

	[self print:@"Peripheral disconnected"];
	self.connectedPeripheral = nil;
	
	// Disable all buttons requiring a connection
	[self disableButtons];
	_learnButton.enabled = NO;
	_connectButton.image = [UIImage imageNamed:@"barbtn_lightning"];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
	[self print:[NSString stringWithFormat:@"Could not connect to peripheral. Error: %@", [error localizedDescription] ]];
}

#pragma mark - CBPeripheralDelegate methods

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
	// Check for error
	if( error != nil )
	{
		// Error
		[self print:[NSString stringWithFormat:@"Error discovering services: %@", [error localizedDescription]]];
		return;
	}
	
	[self print:@"Done discovering services."];
	
	// Find the GCAC service (altough it's the only one we're trying to discover)
	for( CBService *service in peripheral.services )
	{
		if( [service.UUID isEqualToUUIDString:UUID_GCAC_SERVICE] )
		{
			self.GCACService = service;
			[self print:@"Found GCAC service"];
			
			// Find characteristics from GCAC service
			[connectedPeripheral discoverCharacteristics:[NSArray arrayWithObject:[CBUUID UUIDWithString:UUID_COMMAND_CHARATERISTIC]] forService:service];
		}
	}
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
	// Check for error
	if( error != nil )
	{
		// Error
		[self print:[NSString stringWithFormat:@"Error discovering characteristics: %@", [error localizedDescription]]];
		return;
	}
	
	// Which service did we find characteristics for?
	if( service == GCACService )
	{
		// The GCAC service: get pointers to command and response characteristics
		for( CBCharacteristic *characteristic in service.characteristics )
		{
			if( [characteristic.UUID isEqualToUUIDString:UUID_COMMAND_CHARATERISTIC] )
			{
				[self print:@"Found command characteristic"];
				self.GCACCommandCharacteristic = characteristic;
				
				// We have the command characteristic: enable buttons
				[self enableButtons];
				
				// Set toolbar items
				_learnButton.enabled = YES;
				_connectButton.enabled = YES;
				_connectButton.image = [UIImage imageNamed:@"barbtn_disconnect"];
			}
			/* -- We don't care about the response characteristic right now
			else if( [characteristic.UUID isEqualToUUIDString:UUID_RESPONSE_CHARACTERISTIC] )
			{
				[self print:@"Found response characteristic"];
				self.GCACResponseCharacteristic = characteristic;
				
				// Enable notifications for response characteristic
				[peripheral setNotifyValue:YES forCharacteristic:characteristic];
			}
			 */
		}
	}
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
	// Check for error
	if( error != nil )
	{
		// Error
		[self print:@"Error enabling notifications for response characteristic"];
		return;
	}
	
	[self print:@"Response notifications enabled"];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
	// Check for error
	if( error != nil )
	{
		// Error
		[self print:[NSString stringWithFormat:@"Error updating value for characteristic %@: %@", [characteristic.UUID string], [error localizedDescription]]];
		return;
	}
	
	// Get user friendly name for characteristic if possible
	NSString *characteristicName;
	if( characteristic == GCACCommandCharacteristic )
		characteristicName = @"COMMAND";
	else if( characteristic == GCACResponseCharacteristic )
		characteristicName = @"RESPONSE";
	else 
		characteristicName = [characteristic.UUID string];
	
	NSString *valueString = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
	[self print:[NSString stringWithFormat:@"Value updated for %@ = '%@'", characteristicName, valueString]];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
	// Check for error
	if( error != nil )
	{
		// Error
		[self print:[NSString stringWithFormat:@"Error writing command value: %@", [error localizedDescription]]];
		return;
	}
	
	// Should we continue to send the command?
	if( commandMode == CommandModeRepeat )
		// Yes
		[self sendCommand:currentCommandNumber];
}

#pragma mark - UISplitViewController delegate methods

- (void)splitViewController:(UISplitViewController *)svc willHideViewController:(UIViewController *)aViewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)pc
{
	[barButtonItem setImage:[UIImage imageNamed:@"barbtn_debug"]];

	// Add the button to toolbar items array
	NSArray *items = [NSArray arrayWithObjects:barButtonItem, _flexSpace, _learnButton, _connectButton, _debugButton, nil];
	[_toolbar setItems:items animated:YES];
	
	// Remember popover
	self.popover = pc;
}

- (void)splitViewController:(UISplitViewController *)svc willShowViewController:(UIViewController *)aViewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
	// Remove the bar button from toolbar items
	NSArray *items = [NSArray arrayWithObjects:_flexSpace, _learnButton, _connectButton, _debugButton, nil];
	[_toolbar setItems:items animated:YES];
}

#pragma mark - ButtonModelDelegate methods

- (void)repeatCommand:(UIButton*)sender
{
	currentCommandNumber = sender.tag;
	commandMode = CommandModeRepeat;
	
	// Play sound
	[audioPlayer play];
	
	// Send command
	[self sendCommand:currentCommandNumber];
}

/* Stops the repeatable command from transmitting.
 */
- (void)cancelRepeatCommand:(id)sender
{
	// Stop repeating
	commandMode = CommandModeIdle;
}

- (void)sendCommandAction:(UIButton*)sender
{
	// Play sound
	[audioPlayer play];
	
	[self sendCommand:sender.tag];
}

#pragma mark - XML parser methods

- (void)parseXMLFile:(NSString*)xmlFileName
{
	/// TEMP: get from iTunes documents instead
	NSError *error = nil;
	TBXML *xml = [TBXML newTBXMLWithXMLFile:xmlFileName error:&error];
	NSAssert( error == nil, @"Error opening xml file: %@", [error localizedDescription] );
	
	// Iterate pages
	// iPhone or iPad?
	if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
		// iPad: parse and create 
		[self iPad_readPages:xml.rootXMLElement];
	else
		// iPhone: parse and add to mainScroller and titleScroller
		[self iPhone_readPages:xml.rootXMLElement];
}

- (void)iPad_readPages:(TBXMLElement*)rootElement
{
	// Get layout info
	NSString *layoutPlistFilePath;
	
	// iPhone or iPad?
	/// BUG: shouldn't be necessary – iOS 6 doesn't support ~iPad postfix
	if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
		layoutPlistFilePath = [[NSBundle mainBundle] pathForResource:@"coordinates~iPad" ofType:@"plist"];
	else
		layoutPlistFilePath = [[NSBundle mainBundle] pathForResource:@"coordinates" ofType:@"plist"];

	NSDictionary *layoutInfo = [NSDictionary dictionaryWithContentsOfFile:layoutPlistFilePath];
	NSAssert( layoutInfo != nil, @"Error opening layout coordinates file!" );
	
	// Temporary array and dictionary for holding page names and buttons
	NSMutableArray *tmpArray = [[NSMutableArray alloc] init];
	NSMutableDictionary *tmpDictionary = [[NSMutableDictionary alloc] init];
	
	// Iterate pages
	TBXMLElement *page = [TBXML childElementNamed:@"page" parentElement:rootElement];
	while( page )
	{
		int x=0, y=0;	// Coordinates
		
		// Add page name to array
		NSString *pageName = [TBXML valueOfAttributeNamed:@"name" forElement:page];
		[tmpArray addObject:pageName];
		DEBUG_LOG( @"Found page '%@'", pageName );
		
		// Which layout?
		NSString *layout = [TBXML valueOfAttributeNamed:@"layout" forElement:page];
		NSDictionary *pageLayoutInfo = [layoutInfo objectForKey:layout];
		NSAssert1( pageLayoutInfo, @"Unknown page layout: %@", layout );
		
		// Get coords from plist dictionary
		int columns = [[pageLayoutInfo objectForKey:@"columns"] intValue];
		int rows = [[pageLayoutInfo objectForKey:@"rows"] intValue];
		NSString *filenameFormat = [pageLayoutInfo objectForKey:@"filenameFormat"];
		CGFloat initialX = [[pageLayoutInfo objectForKey:@"initialX"] floatValue];
		CGFloat initialY = [[pageLayoutInfo objectForKey:@"initialY"] floatValue];
		CGFloat stepX = [[pageLayoutInfo objectForKey:@"stepX"] floatValue];
		CGFloat stepY = [[pageLayoutInfo objectForKey:@"stepY"] floatValue];
		
		// Create view for this page
		UIView *pageView = [[UIView alloc] initWithFrame:_contentView.bounds];
		pageView.backgroundColor = [UIColor clearColor];
		
		// Iterate rows
		CGFloat xPos;
		CGFloat yPos = initialY;	// Initial y position
		TBXMLElement *rowElement = [TBXML childElementNamed:@"row" parentElement:page];
		while( rowElement )
		{
			// Reset x position
			xPos = initialX;
			
			// Iterate buttons
			TBXMLElement *buttonElement = [TBXML childElementNamed:@"button" parentElement:rowElement];
			while( buttonElement )
			{
				// Instantiate button from XML
				ButtonModel *buttonModel = [ButtonModel buttonModelFromXMLNode:buttonElement];
				
				// Create and configure button
				UIButton *btn = [buttonModel buttonForDelegate:self filenameFormat:filenameFormat];
				if( btn )
				{
					CGRect frame = btn.frame;
					frame.origin = CGPointMake( xPos, yPos );
					btn.frame = frame;
					
					// Add to view
					[pageView addSubview:btn];
				}
				
				// Next button
				xPos += stepX;
				NSAssert( x < columns, @"Too many buttons in row: %s", rowElement->text );
				x++;
				buttonElement = [TBXML nextSiblingNamed:@"button" searchFromElement:buttonElement];
			}
			
			// Next row
			yPos += stepY;
			x = 0;
			NSAssert( y < rows, @"Too many rows in page: %s", page->text );
			y++;
			rowElement = [TBXML nextSiblingNamed:@"row" searchFromElement:rowElement];
		}
		
		// Store view in dictionary with page name as key
		[tmpDictionary setObject:pageView forKey:pageName];
		
		// Next page
		page = [TBXML nextSiblingNamed:@"page" searchFromElement:page];
	}
	
	// Set array and dictionary
	pages = [[NSArray alloc] initWithArray:tmpArray];
	pageContent = [[NSDictionary alloc] initWithDictionary:tmpDictionary];
	
	/// TEMP: select first page
	self.currentButtonsView = [pageContent objectForKey:[pages objectAtIndex:0]];
	currentPageName = [pages objectAtIndex:0];

	// Reload pages list
	[masterViewController.tableView reloadData];
}

- (void)iPhone_readPages:(TBXMLElement*)rootElement
{
	// Get iPhone layout info
	NSString *layoutPlistFilePath = [[NSBundle mainBundle] pathForResource:@"coordinates" ofType:@"plist"];
	NSDictionary *layoutInfo = [NSDictionary dictionaryWithContentsOfFile:layoutPlistFilePath];
	NSAssert( layoutInfo != nil, @"Error opening layout coordinates file!" );
	
	TBXMLElement *page = [TBXML childElementNamed:@"page" parentElement:rootElement];
	NSMutableArray *pageNames = [NSMutableArray array];
	CGFloat pageOffset = 0;
	while( page )
	{
		int x=0, y=0;	// Coordinates
		NSString *pageName = [TBXML valueOfAttributeNamed:@"name" forElement:page];
		[pageNames addObject:pageName];
		DEBUG_LOG( @"Found page '%@'", pageName );
		
		// Which layout?
		NSString *layout = [TBXML valueOfAttributeNamed:@"layout" forElement:page];
		NSDictionary *pageLayoutInfo = [layoutInfo objectForKey:layout];
		NSAssert1( pageLayoutInfo, @"Unknown page layout: %@", layout );
		
		// Get coords from plist dictionary
		int columns = [[pageLayoutInfo objectForKey:@"columns"] intValue];
		int rows = [[pageLayoutInfo objectForKey:@"rows"] intValue];
		NSString *filenameFormat = [pageLayoutInfo objectForKey:@"filenameFormat"];
		CGFloat initialX = [[pageLayoutInfo objectForKey:@"initialX"] floatValue];
		CGFloat initialY = [[pageLayoutInfo objectForKey:@"initialY"] floatValue];
		CGFloat stepX = [[pageLayoutInfo objectForKey:@"stepX"] floatValue];
		CGFloat stepY = [[pageLayoutInfo objectForKey:@"stepY"] floatValue];
		
		// Iterate rows
		CGFloat xPos;
		CGFloat yPos = initialY;	// Initial y position
		TBXMLElement *rowElement = [TBXML childElementNamed:@"row" parentElement:page];
		while( rowElement )
		{
			// Reset x position
			xPos = initialX;
			
			// Iterate buttons
			TBXMLElement *buttonElement = [TBXML childElementNamed:@"button" parentElement:rowElement];
			while( buttonElement )
			{
				// Instantiate button from XML
				ButtonModel *buttonModel = [ButtonModel buttonModelFromXMLNode:buttonElement];
				
				// Create and configure button
				UIButton *btn = [buttonModel buttonForDelegate:self filenameFormat:filenameFormat];
				CGRect frame = btn.frame;
				frame.origin = CGPointMake( xPos + pageOffset, yPos );
				btn.frame = frame;
				
				// Add it
				[_mainScroller addSubview:btn];
				
				// Next button
				xPos += stepX;
				NSAssert( x < columns, @"Too many buttons in row: %s", rowElement->text );
				x++;
				buttonElement = [TBXML nextSiblingNamed:@"button" searchFromElement:buttonElement];
			}
			
			// Next row
			yPos += stepY;
			x = 0;
			NSAssert( y < rows, @"Too many rows in page: %s", page->text );
			y++;
			rowElement = [TBXML nextSiblingNamed:@"row" searchFromElement:rowElement];
		}
		
		// Next page
		pageOffset += _mainScroller.bounds.size.width;
		page = [TBXML nextSiblingNamed:@"page" searchFromElement:page];
	}
	
	// Set content size
	_mainScroller.contentSize = CGSizeMake( pageOffset, _mainScroller.bounds.size.height );
	
	// Set page titles
	[self populateTitleLabelScroller:pageNames];
}

#pragma mark - Other methods

- (void)showLearningAnimation:(BOOL)isLearning
{
	// Create fade-up/fade-down animation to be shown on toolbar and buttons
	CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
    anim.fromValue = [NSNumber numberWithFloat:0.0];
    anim.toValue = [NSNumber numberWithFloat:0.85f];
    anim.duration = 1.0;
	anim.autoreverses = YES;
	anim.repeatCount = MAXFLOAT;	// I.e. infinite
	
	// Are we learnign?
	if( isLearning )
		// Yes: add shadow animation
		[_toolbar.layer addAnimation:anim forKey:@"shadowOpacity"];
	else 
	{
		// No: remove animation
		[_toolbar.layer removeAllAnimations];
		_toolbar.layer.shadowOpacity = 0.0f;
	}
	
	// Change font color on all buttons
	// iPhone or iPad?
	if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
	{
		// iPad: all pages
		for( UIView *view in [pageContent allValues] )
		{
			// Individual buttons
			for( UIView *subview in view.subviews )
			{
				if( [subview isKindOfClass:[UIButton class]] )
				{
					UIButton *button = (UIButton*)subview;	// Typecast
					if( isLearning )
					{
						[button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
						[button setTitleShadowColor:[UIColor whiteColor] forState:UIControlStateNormal];
						
						// Start shadow animation
						[button.layer addAnimation:anim forKey:@"shadowOpacity"];
					}
					else 
					{
						[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
						[button setTitleShadowColor:[UIColor blackColor] forState:UIControlStateNormal];
						
						// Stop animation
						[button.layer removeAllAnimations];
						button.layer.shadowOpacity = 0.0f;
					}
				}
			}	// end-for: subviews
		}	// end-for: [pageContent allValues]
	}
	else
	{
		// iPhone: use mainScroller
		for( UIView *subview in _mainScroller.subviews )
		{		
			if( [subview isKindOfClass:[UIButton class]] )
			{
				UIButton *button = (UIButton*)subview;	// Typecast for your convenience
				if( isLearning )
				{
					[button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
					[button setTitleShadowColor:[UIColor whiteColor] forState:UIControlStateNormal];
					
					// Show shadow. Performance is not good enough for animation
					button.layer.shadowOpacity = 0.85f;
				}
				else 
				{
					[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
					[button setTitleShadowColor:[UIColor blackColor] forState:UIControlStateNormal];
					
					// Hide shadow
					button.layer.shadowOpacity = 0.0f;
				}
			}
		}	// end-for: _mainScroller.subviews
	}
}

- (void)showSplash
{
	UIInterfaceOrientation orientation = self.interfaceOrientation;
	DEBUG_LOG( @"showSplash: orientation: %d", orientation );
	
	// Create image view with image that match device and orientation
	UIImage *image;
	CGAffineTransform transform = CGAffineTransformIdentity;
	CGPoint origin = CGPointZero;
	
	if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
	{
		// iPad: which orientation?
//		[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
//		UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
		if( UIDeviceOrientationIsLandscape( orientation ))
		{
			// We need to rotate image view
			if( orientation == UIDeviceOrientationLandscapeLeft )
			{
				transform = CGAffineTransformMakeRotation( M_PI_2 );
				//	origin = CGPointMake( -20, 0 );
			}
			else if( orientation == UIDeviceOrientationLandscapeRight )
			{
				transform = CGAffineTransformMakeRotation( -M_PI_2 );
				origin = CGPointMake( 20, 0 );
			}
			
			// Load image
			image = [UIImage imageNamed:@"Default-Landscape.png"];
			
		}
		else
		{
			// Rotate if upside-down
			if( orientation == UIDeviceOrientationPortraitUpsideDown )
				transform = CGAffineTransformMakeRotation( M_PI );
			else
				origin = CGPointMake( 0, 20 );
			
			image = [UIImage imageNamed:@"Default-Portrait.png"];
		}
	}
	else
	{
		// iPhone
		image = [UIImage imageNamed:@"Default.png"];
		origin = CGPointMake( 0, -20 );		// Adjust for status bar
	}
	
	
	// Instantiate image view and adjust rotation and origin
	UIImageView *splashView = [[UIImageView alloc] initWithImage:image];
	DEBUG_LOG( @"splashView: %@", splashView );
	[APP.window addSubview:splashView];
	splashView.transform = transform;
	CGRect frame = splashView.frame;
	frame.origin = origin;
	splashView.frame = frame;
	
	frame = CGRectInset( splashView.frame, -splashView.frame.size.width, -splashView.frame.size.height );
//	[UIView animateWithDuration:0.5 delay:1 options:0 animations:^{
//		splashView.alpha = 0;
//		splashView.frame = frame;
//	} completion:^(BOOL finished) {
//		[splashView removeFromSuperview];
//	}];
}

- (void)disableButtons
{
	// iPhone or iPad?
	if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
	{
		// iPad: disable buttons in all views
		for( UIView *view in [pageContent allValues] )
		{
			for( UIView *subview in view.subviews )
				if( [subview isKindOfClass:[UIButton class]] )
					[(UIButton*)subview setEnabled:NO];
		}
	}
	else
	{
		// iPhone: enumerate subviews in mainscroller
		for( UIView *subview in _mainScroller.subviews )
			if( [subview isKindOfClass:[UIButton class]] )
				[(UIButton*)subview setEnabled:NO];
	}
}

- (void)enableButtons
{
	// iPhone or iPad?
	if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
	{
		// iPad: enable buttons in all views
		for( UIView *view in [pageContent allValues] )
		{
			for( UIView *subview in view.subviews )
				if( [subview isKindOfClass:[UIButton class]] )
					[(UIButton*)subview setEnabled:YES];
		}
	}
	else
	{
		// iPhone: enumerate subviews of mainscroller and enable all buttons
		for( UIView *subview in _mainScroller.subviews )
			if( [subview isKindOfClass:[UIButton class]] )
				[(UIButton*)subview setEnabled:YES];
	}
}

- (void)setCurrentButtonsView:(UIView*)currentButtonsView
{
	// Do nothing if we're already showing this view
	if( _currentButtonsView == currentButtonsView )
		return;
	
	// Remember the current view so we can animate it
	UIView *oldButtonsView = _currentButtonsView;
	
	// Update ivar
	_currentButtonsView = currentButtonsView;
	
	// Add and fade in new buttons view
	CGAffineTransform transform = CGAffineTransformMakeScale( 0.1, 0.1 );
	_currentButtonsView.alpha = 0;
	_currentButtonsView.transform = transform;
	[self.contentView addSubview:_currentButtonsView];
	[UIView animateWithDuration:0.3f animations:^{
		_currentButtonsView.alpha = 1;
		_currentButtonsView.transform = CGAffineTransformIdentity;
		
		oldButtonsView.transform = transform;
		oldButtonsView.alpha = 0;
	} completion:^(BOOL finished) {
		[oldButtonsView removeFromSuperview];
	}];
	
	// Dismiss popover controller if visible
	[_popover dismissPopoverAnimated:YES];
}

- (IBAction)scanAction:(id)sender
{
	// Only scan if BT is powered up
	if( centralManager.state != CBCentralManagerStatePoweredOn )
	{
		[self print:@"Bluetooth off – not scanning."];
		return;
	}
	
	// Are we are currently connected?
	if( self.connectedPeripheral )
	{
		[self print:@"Disconnecting..."];
		[centralManager cancelPeripheralConnection:self.connectedPeripheral];
		return;
	}
	
	// Show HUD
	[MBProgressHUD showHUDAddedTo:self.view animated:YES];
	
	// Forget existing
	[peripherals removeAllObjects];
	[peripheralNames removeAllObjects];
	
	// Start scanning - we're only looking for devices with the "Generic Command and Control Protocol" service
	[self print:@"Start scanning..."];
	scanTimer = [NSTimer timerWithTimeInterval:SCAN_TIMEOUT target:self selector:@selector(scanTimeout:) userInfo:nil repeats:NO];
	[[NSRunLoop mainRunLoop] addTimer:scanTimer forMode:NSRunLoopCommonModes];
	
	[centralManager scanForPeripheralsWithServices:[NSArray arrayWithObject:[CBUUID UUIDWithString:UUID_GCAC_SERVICE]] options:0];
	
	// Set toolbar items
	_learnButton.enabled = NO;
	_connectButton.enabled = NO;
}

- (IBAction)disconnectAction:(id)sender
{
	if( self.connectedPeripheral == nil )
	{
		[self print:@"Not connected."];
		return;
	}

	[self print:@"Disconnecting..."];
	[centralManager cancelPeripheralConnection:connectedPeripheral];
}

- (IBAction)clearAction:(id)sender
{
	_textView.text = @"";
}

- (IBAction)forgetPreferredAction:(id)sender
{
	// Forget preferred device
	APP.preferredDeviceUUID = nil;
}

- (IBAction)readAction:(id)sender
{
	if( self.connectedPeripheral == nil )
	{
		[self print:@"Not connected."];
		return;
	}
	
	[self print:@"Reading response characteristic..."];
	[connectedPeripheral readValueForCharacteristic:GCACResponseCharacteristic];
}

- (IBAction)learn:(id)sender
{
	// Toggle recording
	learning = !learning;
	[self showLearningAnimation:learning];
}

- (IBAction)toggleDebugAction:(id)sender
{
	// Is the debugging view already visible?
	if( _debugView.frame.origin.y < self.view.bounds.size.height )
	{
		// Yes: hide it
		CGRect frame = _debugView.frame;
		frame.origin.y = self.view.bounds.size.height;
		
		[UIView animateWithDuration:0.3 animations:^{
			_debugView.frame = frame;
		}];
	}
	else
	{
		// No: show it
		CGRect frame = _debugView.frame;
		frame.origin.y = self.view.bounds.size.height - frame.size.height;
		
		// Weirdness happens here…
		// When we show the debug view, the textView is not updates to show the text.
		// But as soon as the user scrolls the view, it becomes visible.
		// See http://stackoverflow.com/questions/7738666/uitextview-doesnt-show-until-it-is-scrolled
		// Therefore, we clear the text and set it again. Dangit, that should not be necessary!
		DEBUG_LOG( @"Performing ugly hack..." );
		NSString *tmpText = _textView.text;
		_textView.text = @"";
		_textView.text = tmpText;
		[_textView scrollRangeToVisible:NSMakeRange( [_textView.text length]-1, 1 )];

		[UIView animateWithDuration:0.3 animations:^{
			_debugView.frame = frame;
		}];
	}
}

- (IBAction)debug1Action:(id)sender
{
	BOOL isEnabled = NO;
	
	// Are the buttons currently enabled?
	// iPhone or iPad?
	if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
	{
		// iPad: get first button from currentButtonsView
		for( UIView *subview in _currentButtonsView.subviews )
		{
			if( [subview isKindOfClass:[UIButton class]] )
			{
				isEnabled = [(UIButton*)subview isEnabled];
				break;
			}
		}
	}
	else
	{
		// iPhone: get first button in mainScroller
		for( UIView *subview in _mainScroller.subviews )
		{
			if( [subview isKindOfClass:[UIButton class]] )
			{
				isEnabled = [(UIButton*)subview isEnabled];
				break;
			}
		}
	}

	// Enable or disable all buttons
	if( isEnabled )
	{
		[self disableButtons];
		
		// Set toolbar items
		_learnButton.enabled = NO;
		_connectButton.enabled = YES;
		_connectButton.image = [UIImage imageNamed:@"barbtn_lightning"];
	}
	else 
	{
		[self enableButtons];
		
		// Set toolbar items
		_learnButton.enabled = YES;
		_connectButton.enabled = YES;
		_connectButton.image = [UIImage imageNamed:@"barbtn_disconnect"];
	}
}

- (IBAction)choosePageAction:(id)sender
{
	UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Jump to page" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:nil];
	actionSheet.tag = TagJumpToPageActionSheet;
	actionSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
	
	// Iterate pageLabelScroller. Labels are added in left-to-rigth order so we can rely on position in subviews array.
	for( UILabel *subview in _pageLabelScroller.subviews )
	{
		// Make sure it's a label
		if( ![subview isKindOfClass:[UILabel class]] )
			continue;
		
		// Add page title
		[actionSheet addButtonWithTitle:subview.text];
	}
	
	// Show it
	[actionSheet showInView:self.view];
}

- (IBAction)sendLearnAction:(id)sender
{
	if( self.connectedPeripheral == nil )
	{
		[self print:@"Not connected."];
		return;
	}
	
	[self print:@"Sending \"L-000\""];
	[connectedPeripheral writeValue:[@"L-000" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:GCACCommandCharacteristic type:CBCharacteristicWriteWithResponse];
}

- (IBAction)sendTAction:(id)sender
{
	if( self.connectedPeripheral == nil )
	{
		[self print:@"Not connected."];
		return;
	}
	
	[self print:@"Sending \"T-000\""];
	[connectedPeripheral writeValue:[@"T-000" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:GCACCommandCharacteristic type:CBCharacteristicWriteWithResponse];
}

- (IBAction)sendYAction:(id)sender
{
	if( self.connectedPeripheral == nil )
	{
		[self print:@"Not connected."];
		return;
	}
	
	[self print:@"Sending \"Y-000\""];
	[connectedPeripheral writeValue:[@"Y-000" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:GCACCommandCharacteristic type:CBCharacteristicWriteWithResponse];
}

@end
