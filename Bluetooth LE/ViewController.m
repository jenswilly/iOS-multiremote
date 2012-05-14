//
//  ViewController.m
//  Bluetooth LE
//
//  Created by Jens Willy Johannsen on 30-04-12.
//  Copyright (c) 2012 Greener Pastures. All rights reserved.
//

#import "ViewController.h"
#import "CBUUID+Utils.h"
#import "MBProgressHUD.h"
#import "TBXML.h"

#define UUID_GCAC_SERVICE @"b8b96269-562a-408f-8155-0b45f21c7774"
#define UUID_DEVICE_INFORMATION @"180a"
#define UUID_COMMAND_CHARATERISTIC @"bf33aeaf-8653-4841-89c8-330fa4f13346"
#define UUID_RESPONSE_CHARACTERISTIC @"51494780-28c9-4502-87f1-c23881c70300"

// Coordinates for buttons
static const CGFloat xCoords[] = {24, 117, 210};
static const CGFloat yCoords[] = {7, 101, 195, 289};

@interface ViewController ()
- (void)print:(NSString*)text;
- (void)scanTimeout:(NSTimer*)timer;
- (void)toggleDebugMode;
- (void)toggleLearningMode;
- (void)populateTitleLabelScroller:(NSArray*)pageTitles;
- (void)parseXMLFile:(NSString*)xmlFileName;

@end

@implementation ViewController
@synthesize centralManager, peripherals, connectedPeripheral, GCACService, GCACCommandCharacteristic, GCACResponseCharacteristic, peripheralNames;
@synthesize learnButton;
@synthesize debugButton;
@synthesize scanButton;
@synthesize flexSpace;
@synthesize toolbar;
@synthesize pageLabelScroller;
@synthesize textView;
@synthesize debugView;
@synthesize mainScroller;

- (void)viewDidLoad
{
    [super viewDidLoad];

	// Power up Bluetooth LE central manager (main queue)
	centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
	// Wait for callback to report BTLE ready.
	
	// Initialize
	peripherals = [[NSMutableArray alloc] init];
	peripheralNames = [[NSMutableDictionary alloc] init];	
	
	// Set toolbar items
	[toolbar setItems:[NSArray arrayWithObjects:debugButton, flexSpace, nil] animated:YES];
	 
	// Appearance
	[debugButton setBackgroundImage:[UIImage imageNamed:@"topbtn_debug.png"] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
	[scanButton setBackgroundImage:[UIImage imageNamed:@"topbtn_scan.png"] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
	[learnButton setBackgroundImage:[UIImage imageNamed:@"topbtn_learn.png"] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
	
	// Load xml
	[self parseXMLFile:@"remote.xml"];
	
	// Disable all buttons requiring a connection
	[mainScroller.subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		if( [obj isKindOfClass:[UIButton class]] )
			[(UIButton*)obj setEnabled:NO];
	}];
}

- (void)viewDidUnload
{
	[self setTextView:nil];
    [self setDebugView:nil];
	[self setLearnButton:nil];
	[self setDebugButton:nil];
	[self setScanButton:nil];
	[self setMainScroller:nil];
	[self setFlexSpace:nil];
	[self setToolbar:nil];
	[self setPageLabelScroller:nil];
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return UIInterfaceOrientationIsPortrait( interfaceOrientation );
}

#pragma mark - UIScrollViewDelegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	// Calculate position for title scroller: one page in the main scroller corresponds to 80px in the title scroller
	CGFloat titleScrollerOffset = -160 + mainScroller.contentOffset.x / 320 * 80;
	pageLabelScroller.contentOffset = CGPointMake( titleScrollerOffset, 0 );
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
		frame.origin.y = pageLabelScroller.bounds.size.height/2 - frame.size.height/2;
		label.frame = frame;
		xPos += 80;
		maxX = CGRectGetMaxX( label.frame );
		
		[pageLabelScroller addSubview:label];
	}
	
	// Initial position
	pageLabelScroller.contentSize = CGSizeMake( maxX, pageLabelScroller.bounds.size.height );
	pageLabelScroller.contentOffset = CGPointMake( -160, 0 );
}

- (void)toggleDebugMode
{
	// Is the debugging view already visible?
	if( debugView.frame.origin.y < 460 )
	{
		// Yes: hide it
		CGRect frame = debugView.frame;
		frame.origin.y = 460;
		
		[UIView animateWithDuration:0.3 animations:^{
//			debugButton.highlighted = NO;
			debugView.frame = frame;
		}];
	}
	else
	{
		// No: show it
		CGRect frame = debugView.frame;
		frame.origin.y = 460 - frame.size.height;
		
		[UIView animateWithDuration:0.3 animations:^{
//			debugButton.highlighted = YES;
			debugView.frame = frame;
		}];
	}
}

- (void)toggleLearningMode
{
	// Toggle recording
	learning = !learning;
//	learnButton.highlighted = learning;
}

- (void)print:(NSString *)text
{
	DEBUG_LOG( @"--> %@", text );
	textView.text = [textView.text stringByAppendingFormat:@"\r%@", text];
	[textView scrollRangeToVisible:NSMakeRange( [textView.text length]-1, 1 )];
}

- (void)scanTimeout:(NSTimer *)timer
{
	// Stop scanning
	[centralManager stopScan];
	[MBProgressHUD hideHUDForView:self.view animated:YES];
	[self print:@"Done scanning."];
	
	// We're done scanning for devices. If we're not yet connecting, let the user pick a device if we found any
	if( [peripherals count] > 0 )
	{
		// We found some: show action sheet
		UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Connect to device" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:nil];
		
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
		[actionSheet showInView:self.view];
	}
	else 
	{
		[self print:@"... no devices found."];
		
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No devices found" message:@"Make sure the device is switched on and in range." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
		[alert show];
		
		// Set toolbar items
		[toolbar setItems:[NSArray arrayWithObjects:debugButton, flexSpace, scanButton, nil] animated:YES];
		
	}
}

#pragma mark - UIActionSheetDelegate methods

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	// Was it cancel?
	if( buttonIndex == actionSheet.cancelButtonIndex )
		// Yes: do nothing
		return;
	
	// Otherwise, connect to specified device
	[MBProgressHUD showHUDAddedTo:self.view animated:YES];
	CBPeripheral *peripheral = [peripherals objectAtIndex:buttonIndex - 1];	// -1 for the Cancel button
	[centralManager connectPeripheral:peripheral options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
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
	
	// Hide scan button
//	scanButton.hidden = YES;
	
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
	[mainScroller.subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		if( [obj isKindOfClass:[UIButton class]] )
			[(UIButton*)obj setEnabled:NO];
	}];
	[toolbar setItems:[NSArray arrayWithObjects:debugButton, flexSpace, scanButton, nil] animated:YES];
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
			[connectedPeripheral discoverCharacteristics:[NSArray arrayWithObjects:[CBUUID UUIDWithString:UUID_COMMAND_CHARATERISTIC], [CBUUID UUIDWithString:UUID_RESPONSE_CHARACTERISTIC], nil] forService:service];
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
				[mainScroller.subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
					if( [obj isKindOfClass:[UIButton class]] )
						[(UIButton*)obj setEnabled:YES];
				}];
				
				// Set toolbar items
				[toolbar setItems:[NSArray arrayWithObjects:debugButton, flexSpace, learnButton, nil] animated:YES];
			}
			else if( [characteristic.UUID isEqualToUUIDString:UUID_RESPONSE_CHARACTERISTIC] )
			{
				[self print:@"Found response characteristic"];
				self.GCACResponseCharacteristic = characteristic;
				
				// Enable notifications for response characteristic
				[peripheral setNotifyValue:YES forCharacteristic:characteristic];
			}
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
		[self print:[NSString stringWithFormat:@"Error writing command value: %@", [characteristic.UUID string], [error localizedDescription]]];
		return;
	}
	
	[self print:@"Write characteristic done."];
}

#pragma mark - Public methods

- (IBAction)scanAction:(id)sender
{
	// Show HUD
	[MBProgressHUD showHUDAddedTo:self.view animated:YES];
	
	// Forget existing
	[peripherals removeAllObjects];
	[peripheralNames removeAllObjects];
	
	// Start scanning - we're only looking for devices with the "Generic Command and Control Protocol" service
	[self print:@"Start scanning..."];
	scanTimer = [NSTimer scheduledTimerWithTimeInterval:2.0f target:self selector:@selector(scanTimeout:) userInfo:nil repeats:NO];
	[centralManager scanForPeripheralsWithServices:[NSArray arrayWithObject:[CBUUID UUIDWithString:UUID_GCAC_SERVICE]] options:0];
	
	// Set toolbar items
	[toolbar setItems:[NSArray arrayWithObjects:debugButton, flexSpace, nil] animated:YES];
}

- (IBAction)sendCommandAction:(UIButton*)sender
{
	if( self.connectedPeripheral == nil )
	{
		[self print:@"Not connected."];
		return;
	}
	
	// Build command string
	NSString *commandPrefix = (learning ? @"L" : @"S");
	NSString *commandString = [NSString stringWithFormat:@"%@-%03d", commandPrefix, sender.tag];
	[self print:[NSString stringWithFormat:@"Sending \"%@", commandString]];
	[connectedPeripheral writeValue:[commandString dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:GCACCommandCharacteristic type:CBCharacteristicWriteWithResponse];

	// Not learning anymore
	if( learning )
	{
		learning = NO;
//		learnButton.highlighted = NO;
	}
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
	textView.text = @"";
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
	// Schedule this on the main thread so we can change the button's state
	[self performSelectorOnMainThread:@selector(toggleLearningMode) withObject:nil waitUntilDone:NO];
}

- (IBAction)toggleDebugAction:(id)sender
{
	// Schedule this on the main thread so we can change the button's state
	[self performSelectorOnMainThread:@selector(toggleDebugMode) withObject:nil waitUntilDone:NO];
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

#pragma mark - XML parser methods

- (void)parseXMLFile:(NSString*)xmlFileName
{
	/// TEMP: get from iTunes documents instead
	NSError *error = nil;
	TBXML *xml = [TBXML newTBXMLWithXMLFile:xmlFileName error:&error];
	NSAssert( error == nil, @"Error opening xml file: %@", [error localizedDescription] );
	
	// Iterate pages
	TBXMLElement *page = [TBXML childElementNamed:@"page" parentElement:xml.rootXMLElement];
	NSMutableArray *pageNames = [NSMutableArray array];
	CGFloat pageOffset = 0;
	while( page )
	{
		int x=0, y=0;	// Coordinates
		NSString *pageName = [TBXML valueOfAttributeNamed:@"name" forElement:page];
		[pageNames addObject:pageName];
		DEBUG_LOG( @"Found page '%@'", pageName );
		
		// Iterate rows
		TBXMLElement *row = [TBXML childElementNamed:@"row" parentElement:page];
		while( row )
		{
			// Iterate buttons
			TBXMLElement *button = [TBXML childElementNamed:@"button" parentElement:row];
			while( button )
			{
				// Extract attributes
				NSString *color = [TBXML valueOfAttributeNamed:@"color" forElement:button];
				NSString *text = [TBXML valueOfAttributeNamed:@"text" forElement:button];
				NSString *image = [TBXML valueOfAttributeNamed:@"image" forElement:button];
				NSUInteger number = [[TBXML valueOfAttributeNamed:@"id" forElement:button] intValue];
				
				// Make sure we have color and either text or image
				if( [color length] > 0 && ([text length] > 0 || [image length] > 0) )
				{
					// Create and congure button
					UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
					btn.frame = CGRectMake( xCoords[x] + pageOffset, yCoords[y], 86, 86 );
					[btn setBackgroundImage:[UIImage imageNamed:[NSString stringWithFormat:@"btn_%@.png", color]] forState:UIControlStateNormal];
					
					// Do we have text?
					if( [text length] > 0 )
					{
						// Yes: configure label
						btn.titleLabel.textColor = [UIColor whiteColor];
						btn.titleLabel.shadowColor = [UIColor blackColor];
						btn.titleLabel.shadowOffset = CGSizeMake( 0, 1 );
						btn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
						[btn setTitle:text forState:UIControlStateNormal];
					}
					else 
					{
						// Otherwise we must have an image: set image
						[btn setImage:[UIImage imageNamed:image] forState:UIControlStateNormal];
					}
					
					btn.tag = number;
					[btn addTarget:self action:@selector(sendCommandAction:) forControlEvents:UIControlEventTouchUpInside];
					[mainScroller addSubview:btn];
					
				}
				
				// Next button
				NSAssert( x <= 2, @"Too many buttons in row: %s", row->text );
				x++;
				button = [TBXML nextSiblingNamed:@"button" searchFromElement:button];
			}
			
			// Next row
			x = 0;
			NSAssert( y <= 3, @"Too many rows in page: %s", page->text );
			y++;
			row = [TBXML nextSiblingNamed:@"row" searchFromElement:row];
		}
		
		// Next page
		pageOffset += mainScroller.bounds.size.width;
		page = [TBXML nextSiblingNamed:@"page" searchFromElement:page];
	}
	
	// Set content size
	mainScroller.contentSize = CGSizeMake( pageOffset, mainScroller.bounds.size.height );

	// Set page titles
	[self populateTitleLabelScroller:pageNames];
}

@end
