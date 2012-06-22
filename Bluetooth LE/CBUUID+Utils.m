//
//  CBUUID+Utils.m
//  Bluetooth LE
//
//  Created by Jens Willy Johannsen on 01-05-12.
//  Copyright (c) 2012 Greener Pastures. All rights reserved.
//

#import "CBUUID+Utils.h"

@implementation CBUUID (Utils)

- (NSString*)string
{
	return [[NSString alloc] initWithData:[self data] encoding:NSUTF8StringEncoding];
}

+ (NSString*)stringFromCFUUIDRef:(CFUUIDRef)uuid
{
	if( !uuid )
		return nil;
	
    CFStringRef string = CFUUIDCreateString( NULL, uuid );
	return (__bridge_transfer NSString*)string;
}

/* Equality
 * instances are considered equal if their IDs are equal (regardless if the rest of the data is different)
 */
- (BOOL)isEqualToUUID:(id)other
{
    if( self == other )
        return YES;        // identity equality
    
    if( ![other isKindOfClass:[CBUUID class]] )
        return NO;        // wrong class

    // Compare data
	return [[self data] isEqualToData:[(CBUUID*)other data]];
}

- (BOOL)isEqualToUUIDString:(NSString*)otherString
{
	NSString *string1 = [[[[self data] description]
							   stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]]
							  stringByReplacingOccurrencesOfString:@" " withString:@""];
	NSString *string2 = [otherString stringByReplacingOccurrencesOfString:@"-" withString:@""];
	
    // Compare data
	return [string1 isEqualToString:string2];
}
@end
