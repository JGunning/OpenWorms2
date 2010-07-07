//
//  overlayViewController.m
//  HedgewarsMobile
//
//  Created by Vittorio on 16/03/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "OverlayViewController.h"
#import "SDL_uikitappdelegate.h"
#import "PascalImports.h"
#import "CGPointUtils.h"
#import "SDL_mouse.h"
#import "SDL_config_iphoneos.h"
#import "PopoverMenuViewController.h"
#import "CommodityFunctions.h"

#define HIDING_TIME_DEFAULT [NSDate dateWithTimeIntervalSinceNow:2.7]
#define HIDING_TIME_NEVER   [NSDate dateWithTimeIntervalSinceNow:10000]


@implementation OverlayViewController
@synthesize popoverController, popupMenu, writeChatTextField, spinningWheel;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation {
    return rotationManager(interfaceOrientation);
}

-(void) didRotate:(NSNotification *)notification {  
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    CGRect rect = [[UIScreen mainScreen] bounds];
    CGRect usefulRect = CGRectMake(0, 0, rect.size.width, rect.size.height);
    UIView *sdlView = [[[UIApplication sharedApplication] keyWindow] viewWithTag:12345];
    
    [UIView beginAnimations:@"rotation" context:NULL];
    [UIView setAnimationDuration:0.8f];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    switch (orientation) {
        case UIDeviceOrientationLandscapeLeft:
            sdlView.transform = CGAffineTransformMakeRotation(degreesToRadian(0));
            self.view.transform = CGAffineTransformMakeRotation(degreesToRadian(90));
            [self chatDisappear];
            HW_setLandscape(YES);
            break;
        case UIDeviceOrientationLandscapeRight:
            sdlView.transform = CGAffineTransformMakeRotation(degreesToRadian(180));
            self.view.transform = CGAffineTransformMakeRotation(degreesToRadian(-90));
            [self chatDisappear];
            HW_setLandscape(YES);
            break;
        /*
        case UIDeviceOrientationPortrait:
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                sdlView.transform = CGAffineTransformMakeRotation(degreesToRadian(270));
                self.view.transform = CGAffineTransformMakeRotation(degreesToRadian(0));
                [self chatAppear];
                HW_setLandscape(NO);
            }
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                sdlView.transform = CGAffineTransformMakeRotation(degreesToRadian(90));
                self.view.transform = CGAffineTransformMakeRotation(degreesToRadian(180));
                [self chatAppear];
                HW_setLandscape(NO);
            }
            break;
        */
        default:
            break;
    }
    self.view.frame = usefulRect;
    //sdlView.frame = usefulRect;
    [UIView commitAnimations];
}

-(void) chatAppear {
    /*
    if (writeChatTextField == nil) {
        writeChatTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 100, 768, [UIFont systemFontSize]+8)];
        writeChatTextField.textColor = [UIColor whiteColor];
        writeChatTextField.backgroundColor = [UIColor blueColor];
        writeChatTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        writeChatTextField.autocorrectionType = UITextAutocorrectionTypeNo;
        writeChatTextField.enablesReturnKeyAutomatically = NO;
        writeChatTextField.keyboardAppearance = UIKeyboardAppearanceDefault;
        writeChatTextField.keyboardType = UIKeyboardTypeDefault;
        writeChatTextField.returnKeyType = UIReturnKeyDefault;
        writeChatTextField.secureTextEntry = NO;    
        [self.view addSubview:writeChatTextField];
    }
    writeChatTextField.alpha = 1;
    [self activateOverlay];
    [dimTimer setFireDate:HIDING_TIME_NEVER];
    */
}

-(void) chatDisappear {
    /*
    writeChatTextField.alpha = 0;
    [writeChatTextField resignFirstResponder];
    [dimTimer setFireDate:HIDING_TIME_DEFAULT];
    */
}

#pragma mark -
#pragma mark View Management
-(void) viewDidLoad {
    isPopoverVisible = NO;
    singleton = self.spinningWheel;
    canDim = NO;
    self.view.alpha = 0;
    self.view.center = CGPointMake(self.view.frame.size.height/2.0, self.view.frame.size.width/2.0);
    
    // set initial orientation
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    UIView *sdlView = [[[UIApplication sharedApplication] keyWindow] viewWithTag:12345];
    switch (orientation) {
        case UIDeviceOrientationLandscapeLeft:
            sdlView.transform = CGAffineTransformMakeRotation(degreesToRadian(0));
            self.view.transform = CGAffineTransformMakeRotation(degreesToRadian(90));
            break;
        case UIDeviceOrientationLandscapeRight:
            sdlView.transform = CGAffineTransformMakeRotation(degreesToRadian(180));
            self.view.transform = CGAffineTransformMakeRotation(degreesToRadian(-90));
            break;
    }
    CGRect rect = [[UIScreen mainScreen] bounds];
    self.view.frame = CGRectMake(0, 0, rect.size.width, rect.size.height);
    
    dimTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:6]
                                        interval:1000
                                          target:self
                                        selector:@selector(dimOverlay)
                                        userInfo:nil
                                         repeats:YES];
    
    // add timer too runloop, otherwise it doesn't work
    [[NSRunLoop currentRunLoop] addTimer:dimTimer forMode:NSDefaultRunLoopMode];
    
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];   
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didRotate:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];

    [UIView beginAnimations:@"showing overlay" context:NULL];
    [UIView setAnimationDuration:1];
    self.view.alpha = 1;
    [UIView commitAnimations];
}

/* these are causing problems at reloading so let's remove 'em
-(void) viewDidUnload {
    [popoverController dismissPopoverAnimated:NO];
    [dimTimer invalidate];
    self.writeChatTextField = nil;
    self.popoverController = nil;
    self.popupMenu = nil;
    self.spinningWheel = nil;
    [super viewDidUnload];
    MSG_DIDUNLOAD();
}

-(void) didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
    if (popupMenu.view.superview == nil) 
        popupMenu = nil;
    MSG_MEMCLEAN();
}
*/

-(void) dealloc {
    [writeChatTextField release];
    [popupMenu release];
    [popoverController release];
    // dimTimer is autoreleased
    [spinningWheel release];
    [super dealloc];
}

#pragma mark -
#pragma mark Overlay actions and members
// nice transition for dimming, should be called only by the timer himself
-(void) dimOverlay {
    if (canDim) {
        [UIView beginAnimations:@"overlay dim" context:NULL];
        [UIView setAnimationDuration:0.6];
        self.view.alpha = 0.2;
        [UIView commitAnimations];
    }
}

// set the overlay visible and put off the timer for enough time
-(void) activateOverlay {
    self.view.alpha = 1;
    [dimTimer setFireDate:HIDING_TIME_NEVER];
}

// dim the overlay when there's no more input for a certain amount of time
-(IBAction) buttonReleased:(id) sender {
    UIButton *theButton = (UIButton *)sender;
    
    switch (theButton.tag) {
        case 0:
        case 1:
        case 2:
        case 3:
            HW_walkingKeysUp();
            break;
        case 4:
        case 5:
        case 6:
            HW_otherKeysUp();
            break;
        default:
            NSLog(@"Nope");
            break;
    }

    [dimTimer setFireDate:HIDING_TIME_DEFAULT];
}

// issue certain action based on the tag of the button 
-(IBAction) buttonPressed:(id) sender {
    [self activateOverlay];
    if (isPopoverVisible) {
        [self dismissPopover];
    }
    UIButton *theButton = (UIButton *)sender;
    
    switch (theButton.tag) {
        case 0:
            HW_walkLeft();
            break;
        case 1:
            HW_walkRight();
            break;
        case 2:
            HW_aimUp();
            break;
        case 3:
            HW_aimDown();
            break;
        case 4:
            HW_shoot();
            break;
        case 5:
            HW_jump();
            break;
        case 6:
            HW_backjump();
            break;
        case 7:
            HW_tab();
            break;
        case 10:
            [self showPopover];
            break;
        case 11:
            HW_ammoMenu();
            break;
        default:
            DLog(@"Nope");
            break;
    }
}

// present a further check before closing game
-(void) actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger) buttonIndex {
    if ([actionSheet cancelButtonIndex] != buttonIndex)
        HW_terminate(NO);
    else
        HW_pause();     
}

// show up a popover containing a popupMenuViewController; we hook it with setPopoverContentSize
// on iphone instead just use the tableViewController directly (and implement manually all animations)
-(IBAction) showPopover{
    isPopoverVisible = YES;

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if (popupMenu == nil) 
            popupMenu = [[PopoverMenuViewController alloc] initWithStyle:UITableViewStylePlain];
        if (popoverController == nil) {
            popoverController = [[UIPopoverController alloc] initWithContentViewController:popupMenu];
            [popoverController setPopoverContentSize:CGSizeMake(220, 170) animated:YES];
            [popoverController setPassthroughViews:[NSArray arrayWithObject:self.view]];
        }

        [popoverController presentPopoverFromRect:CGRectMake(1000, 0, 220, 32)
                                           inView:self.view
                         permittedArrowDirections:UIPopoverArrowDirectionUp
                                         animated:YES];
    } else {
        if (popupMenu == nil) {
            popupMenu = [[PopoverMenuViewController alloc] initWithStyle:UITableViewStyleGrouped];
            popupMenu.view.backgroundColor = [UIColor clearColor];
            popupMenu.view.frame = CGRectMake(480, 0, 200, 170);
        }
        [self.view addSubview:popupMenu.view];
        
        [UIView beginAnimations:@"showing popover" context:NULL];
        [UIView setAnimationDuration:0.35];
        popupMenu.view.frame = CGRectMake(280, 0, 200, 170);
        [UIView commitAnimations];
    }
    popupMenu.tableView.scrollEnabled = NO;
}

// on ipad just dismiss it, on iphone transtion to the right
-(void) dismissPopover {
    if (YES == isPopoverVisible) {
        isPopoverVisible = NO;
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [popoverController dismissPopoverAnimated:YES];
        } else {
            [UIView beginAnimations:@"hiding popover" context:NULL];
            [UIView setAnimationDuration:0.35];
            popupMenu.view.frame = CGRectMake(480, 0, 200, 170);
            [UIView commitAnimations];
        
            [popupMenu.view performSelector:@selector(removeFromSuperview) withObject:nil afterDelay:0.35];
        }
        [self buttonReleased:nil];
    }
}

-(void) textFieldDoneEditing:(id) sender{
    [sender resignFirstResponder];
}

// this function is called by pascal FinishProgress and removes the spinning wheel when loading is done
void spinningWheelDone (void) {
    [singleton stopAnimating];
    singleton = nil;
    canDim = YES;
}

#pragma mark -
#pragma mark Custom touch event handling
-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    NSArray *twoTouches;
    UITouch *touch = [touches anyObject];
    CGRect screen = [[UIScreen mainScreen] bounds];
    CGPoint currentPosition = [touch locationInView:self.view];
    
    if (isPopoverVisible) {
        [self dismissPopover];
    }
    if (writeChatTextField) {
        [self.writeChatTextField resignFirstResponder];
        [dimTimer setFireDate:HIDING_TIME_DEFAULT];
    }
    
    if (currentPosition.y < screen.size.width - 120) {
        switch ([touches count]) {
            case 1:
                DLog(@"X:%d Y:%d", HWX(currentPosition.x), HWY(currentPosition.y));
                HW_setCursor(HWX(currentPosition.x), HWY(currentPosition.y));
                if (2 == [touch tapCount])
                    HW_zoomReset();
                break;
            case 2:                
                // pinching
                twoTouches = [touches allObjects];
                UITouch *first = [twoTouches objectAtIndex:0];
                UITouch *second = [twoTouches objectAtIndex:1];
                initialDistanceForPinching = distanceBetweenPoints([first locationInView:self.view], [second locationInView:self.view]);
                break;
            default:
                break;
        }
    }
}

-(void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    initialDistanceForPinching = 0;
    //HW_allKeysUp();
    HW_click();
}

-(void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    // this can happen if the user puts more than 5 touches on the screen at once, or perhaps in other circumstances
    [self touchesEnded:touches withEvent:event];
}

-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    CGRect screen = [[UIScreen mainScreen] bounds];
    
    NSArray *twoTouches;
    CGPoint currentPosition;
    UITouch *touch = [touches anyObject];

    switch ([touches count]) {
        case 1:
            if (HW_isAmmoOpen()) {
                currentPosition = [touch locationInView:self.view];
                DLog(@"X:%d Y:%d", HWX(currentPosition.x), HWY(currentPosition.y));
                HW_setCursor(HWX(currentPosition.x), HWY(currentPosition.y));
            }
            break;
        case 2:
            twoTouches = [touches allObjects];
            UITouch *first = [twoTouches objectAtIndex:0];
            UITouch *second = [twoTouches objectAtIndex:1];
            CGFloat currentDistanceOfPinching = distanceBetweenPoints([first locationInView:self.view], [second locationInView:self.view]);
            const int pinchDelta = 40;
            
            if (0 != initialDistanceForPinching) {
                if (currentDistanceOfPinching - initialDistanceForPinching > pinchDelta) {
                    HW_zoomIn();
                    initialDistanceForPinching = currentDistanceOfPinching;
                }
                else if (initialDistanceForPinching - currentDistanceOfPinching > pinchDelta) {
                    HW_zoomOut();
                    initialDistanceForPinching = currentDistanceOfPinching;
                }
            } else 
                initialDistanceForPinching = currentDistanceOfPinching;
            
            break;
        default:
            break;
    }
}


@end
