//
//  ViewController.h
//  Bluetooth LE
//
//  Created by Jens Willy Johannsen on 30-04-12.
//  Copyright (c) 2012 Greener Pastures. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <AVFoundation/AVFoundation.h>

typedef enum
{
	CommandModeIdle,
	CommandModeSingle,
	CommandModeRepeat
} CommandMode;

@interface MainViewController : UIViewController <CBCentralManagerDelegate, CBPeripheralDelegate, UIActionSheetDelegate, UIScrollViewDelegate, UISplitViewControllerDelegate>
{
	NSTimer *scanTimer;
	BOOL learning;
	AVAudioPlayer *audioPlayer;
	NSUInteger currentCommandNumber;
	CommandMode commandMode;
}

@property (strong) CBCentralManager *centralManager;
@property (strong) NSMutableArray *peripherals;
@property (strong) NSMutableDictionary *peripheralNames;
@property (strong) CBPeripheral *connectedPeripheral;
@property (weak) CBService *GCACService;
@property (weak) CBCharacteristic *GCACCommandCharacteristic;
@property (weak) CBCharacteristic *GCACResponseCharacteristic;
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIView *debugView;
@property (weak, nonatomic) IBOutlet UIScrollView *mainScroller;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *learnButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *debugButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *scanButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *flexSpace;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet UIScrollView *pageLabelScroller;

- (IBAction)scanAction:(id)sender;
- (IBAction)sendCommandAction:(id)sender;
- (IBAction)disconnectAction:(id)sender;
- (IBAction)clearAction:(id)sender;
- (IBAction)forgetPreferredAction:(id)sender;
- (IBAction)readAction:(id)sender;
- (IBAction)sendLearnAction:(id)sender;
- (IBAction)sendTAction:(id)sender;
- (IBAction)sendYAction:(id)sender;
- (IBAction)learn:(id)sender;
- (IBAction)toggleDebugAction:(id)sender;
- (IBAction)debug1Action:(id)sender;
- (IBAction)repeatCommand:(UIButton*)sender;
- (IBAction)cancelRepeatCommand:(id)sender;

@end
