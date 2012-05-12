//
//  AppDelegate.h
//  Bluetooth LE
//
//  Created by Jens Willy Johannsen on 30-04-12.
//  Copyright (c) 2012 Greener Pastures. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong) CBUUID *preferredDeviceUUID;

- (void)savePreferredDevice;
- (void)loadPreferredDevice;
- (void)setAppearance;

@end
