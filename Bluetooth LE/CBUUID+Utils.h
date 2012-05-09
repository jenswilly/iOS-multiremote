//
//  CBUUID+Utils.h
//  Bluetooth LE
//
//  Created by Jens Willy Johannsen on 01-05-12.
//  Copyright (c) 2012 Greener Pastures. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>

@interface CBUUID (Utils)

- (NSString*)string;
+ (NSString*)stringFromCFUUIDRef:(CFUUIDRef)uuid;
- (BOOL)isEqualToUUID:(id)otherUUID;
- (BOOL)isEqualToUUIDString:(NSString*)otherString;

@end
