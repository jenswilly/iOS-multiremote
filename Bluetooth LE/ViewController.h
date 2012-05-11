//
//  ViewController.h
//  Bluetooth LE
//
//  Created by Jens Willy Johannsen on 30-04-12.
//  Copyright (c) 2012 Greener Pastures. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface ViewController : UIViewController <CBCentralManagerDelegate, CBPeripheralDelegate, UIActionSheetDelegate>
{
	NSTimer *scanTimer;
	BOOL learning;
}

@property (strong) CBCentralManager *centralManager;
@property (strong) NSMutableArray *peripherals;
@property (strong) NSMutableDictionary *peripheralNames;
@property (strong) CBPeripheral *connectedPeripheral;
@property (weak) CBService *GCACService;
@property (weak) CBCharacteristic *GCACCommandCharacteristic;
@property (weak) CBCharacteristic *GCACResponseCharacteristic;
@property (weak, nonatomic) IBOutlet UIButton *learnButton;
@property (weak, nonatomic) IBOutlet UIButton *debugButton;
@property (weak, nonatomic) IBOutlet UIButton *scanButton;

@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIView *debugView;
@property (strong, nonatomic) IBOutletCollection(UIButton) NSArray *mustBeConnectedButtons;

- (IBAction)scanAction:(id)sender;
- (IBAction)sendCommandAction:(id)sender;
- (IBAction)disconnectAction:(id)sender;
- (IBAction)clearAction:(id)sender;
- (IBAction)forgetPreferredAction:(id)sender;
- (IBAction)readAction:(id)sender;
- (IBAction)sendLearnAction:(id)sender;
- (IBAction)sendTAction:(id)sender;
- (IBAction)sendYAction:(id)sender;
- (IBAction)learn:(UIButton*)sender;
- (IBAction)toggleDebugAction:(UIButton *)sender;

@end
