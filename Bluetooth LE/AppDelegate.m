//
//  AppDelegate.m
//  Bluetooth LE
//
//  Created by Jens Willy Johannsen on 30-04-12.
//  Copyright (c) 2012 Greener Pastures. All rights reserved.
//

#import "AppDelegate.h"
#import "CBUUID+Utils.h"
#import "MainViewController.h"
#import "PageListViewController.h"

static NSString* const kUserDefaults_PreferredDeviceKey = @"kUserDefaults_PreferredDeviceKey";

@implementation AppDelegate

@synthesize window = _window, preferredDeviceUUID;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	// Set split view controller's delegate (can't do this in IB for some reason)
	if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
	{
		[(UISplitViewController*)_window.rootViewController setDelegate:[self mainViewController]];
	}
	
	[self.window makeKeyAndVisible];
	[self setAppearance];

	// Show splash screen _after_ application:didFinishLaunchingWithOptions: has returned.
	// Only at that point can [[UIDevice currentDevice] orientation] be relied on.
	// [self performSelectorOnMainThread:@selector(showSplash) withObject:nil waitUntilDone:NO];

    return YES;
}
	
- (void)showSplash
{
	DEBUG_POSITION;
	
	// Create image view with image that match device and orientation
	UIImage *image;
	CGAffineTransform transform = CGAffineTransformIdentity;
	CGPoint origin = CGPointZero;
	
	if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
	{
		// iPad: which orientation?
		[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
		UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
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
	[self.window addSubview:splashView];
	splashView.transform = transform;
	CGRect frame = splashView.frame;
	frame.origin = origin;
	splashView.frame = frame;
	
	frame = CGRectInset( splashView.frame, -splashView.frame.size.width, -splashView.frame.size.height );
	[UIView animateWithDuration:0.5 delay:1 options:0 animations:^{
		splashView.alpha = 0;
		splashView.frame = frame;
	} completion:^(BOOL finished) {
		[splashView removeFromSuperview];
	}];
}

/* Returns the main view controller
 */
- (MainViewController*)mainViewController
{
	// iPhone or iPad?
	if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
	{
		// iPad-specific interface here
		UISplitViewController *splitViewController = (UISplitViewController*)_window.rootViewController;
		return [splitViewController.viewControllers objectAtIndex:1];
	}
	else
	{
		// iPhone and iPod touch interface here
		return (MainViewController*)_window.rootViewController;
	}
}

- (void)applicationWillResignActive:(UIApplication *)application
{
	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	[self savePreferredDevice];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
	// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	[self loadPreferredDevice];
	
	// Connect if not already connected and Bluetooth ready
	MainViewController *viewController = [self mainViewController];
	if( !viewController.connectedPeripheral && viewController.centralManager.state == CBCentralManagerStatePoweredOn )
		[viewController scanAction:nil];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)savePreferredDevice
{
	DEBUG_POSITION;
	
	if( preferredDeviceUUID == nil )
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:kUserDefaults_PreferredDeviceKey];
	else 
	{
		NSData *UUIDData = [preferredDeviceUUID data];
		[[NSUserDefaults standardUserDefaults] setObject:UUIDData forKey:kUserDefaults_PreferredDeviceKey];
	}
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)loadPreferredDevice
{
	DEBUG_POSITION;
	
	NSData *UUIDData = [[NSUserDefaults standardUserDefaults] objectForKey:kUserDefaults_PreferredDeviceKey];
	if( UUIDData != nil )
		preferredDeviceUUID = [CBUUID UUIDWithData:UUIDData];
}

- (void)setAppearance
{
	[[UIToolbar appearance] setBackgroundImage:[UIImage imageNamed:@"toolbar.png"] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
	[[UINavigationBar appearance] setBackgroundImage:[UIImage imageNamed:@"toolbar.png"] forBarMetrics:UIBarMetricsDefault];
	[[UINavigationBar appearance] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
														  [UIColor whiteColor], UITextAttributeTextColor,
														  [UIColor blackColor], UITextAttributeTextShadowColor,
														  [NSValue valueWithCGSize:CGSizeMake(0, 1)], UITextAttributeTextShadowOffset,
														  nil]];
	
	[[UIBarButtonItem appearance] setBackgroundImage:[UIImage imageNamed:@"metal_btn"] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
}
@end
