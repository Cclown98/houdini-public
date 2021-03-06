//
//  HomeViewController.m
//  houdini
//
//  Created by Abraham Masri on 11/13/17.
//  Copyright © 2017 Abraham Masri. All rights reserved.
//

#import "HomeViewController.h"
#include "task_ports.h"
#include "triple_fetch_remote_call.h"
#include "apps_control.h"
#include "utilities.h"
#include "QuickActionsViewController.h"
#include <objc/runtime.h>

#include <sys/utsname.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <sys/sysctl.h>

@interface HomeViewController ()
@property (weak, nonatomic) IBOutlet UILabel *deviceModelLabel;
@property (weak, nonatomic) IBOutlet UILabel *osVersionLabel;


@property (weak, nonatomic) IBOutlet UILabel *appcCountLabel;

@property (weak, nonatomic) IBOutlet UILabel *availableStorageLabel;
@property (weak, nonatomic) IBOutlet UIStackView *appsStorageView;

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spaceInfoIndicator;

@property (weak, nonatomic) IBOutlet UIView *respringView;
@property (weak, nonatomic) IBOutlet UIView *rebootView;
@property (weak, nonatomic) IBOutlet UIView *clearSpaceView;
@property (weak, nonatomic) IBOutlet UISwitch *disableSystemUpdatesSwitch;
@property (strong, nonatomic) IBOutlet UIStackView *quickActionsView;

@property (strong, nonatomic) IBOutlet UIButton *quickActionsButton;

@end

@implementation HomeViewController

-(NSString *)get_space_left {
    const char *path = [[NSFileManager defaultManager] fileSystemRepresentationWithPath:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]];
    
    struct statfs stats;
    statfs(path, &stats);

    return [NSByteCountFormatter stringFromByteCount:(float)(stats.f_bavail * stats.f_bsize)
                                          countStyle:NSByteCountFormatterCountStyleFile];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //  quick actions on smaller screens
    
    struct utsname u;
    uname(&u);
#define __viewDidLoad_delen 4
    char *ade = u.machine;
    char *de[__viewDidLoad_delen] = {"iPhone6,1", "iPhone6,2", "iPhone8,4", "iPod7,1"};
    for (int i = 0; i < __viewDidLoad_delen; ++i) {
        if (strcmp(ade, de[i]) == 0) {
            [_quickActionsView setHidden:YES];
            [_quickActionsButton setHidden:NO];
        }
    }
    extern NSMutableDictionary *all_apps;
    if(all_apps == NULL) {
        
        [self.appcCountLabel setHidden:YES];
        [self.availableStorageLabel setHidden:YES];
        [self.spaceInfoIndicator setHidden:NO];
        
        printf("[INFO]: refreshing apps list..\n");
        list_applications_installed();
    }

    // get system/device info
    [self.osVersionLabel setText:[[UIDevice currentDevice] systemVersion]];
    
    size_t len = 0;
    char *model = malloc(len * sizeof(char));
    sysctlbyname("hw.model", NULL, &len, NULL, 0);
    if (len) {
        sysctlbyname("hw.model", model, &len, NULL, 0);
        printf("[INFO]: model internal name: %s (%s)\n", model, [[[UIDevice currentDevice] systemVersion] UTF8String]);
    }
    
    [self.deviceModelLabel setText:[NSString stringWithFormat:@"%s", model]];
    
    
    // reveal the data
    [self.appcCountLabel setText:[NSString stringWithFormat:@"%lu apps installed", (unsigned long)[all_apps count]]];
    [self.availableStorageLabel setText:[NSString stringWithFormat:@"%@ left", [self get_space_left]]];
    
    [self.appcCountLabel setHidden:NO];
    [self.availableStorageLabel setHidden:NO];
    [self.spaceInfoIndicator setHidden:YES];
    
    // check if we already disabled system updates and set the toggle
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"system_updates_disabled"] isEqual:nil]) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"system_updates_disabled"];
    }
    self.disableSystemUpdatesSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"system_updates_disabled"];
    
    // recognize taps
    [self.appsStorageView addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                                initWithTarget:self
                                                action:@selector(appsStorageViewTapped:)]];
    
    [self.respringView addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                                initWithTarget:self
                                                action:@selector(didTapRespring:)]];
    
    [self.rebootView addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                             initWithTarget:self
                                             action:@selector(didTapReboot:)]];
    
    [self.clearSpaceView addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                             initWithTarget:self
                                             action:@selector(didTapClearSpace:)]];
}



- (void)appsStorageViewTapped:(UITapGestureRecognizer *)gestureRecognizer {
    [self.availableStorageLabel setText:[NSString stringWithFormat:@"%@ space left", [self get_space_left]]];
}

- (void)didTapRespring:(UITapGestureRecognizer *)gestureRecognizer {

    uicache(); // two in one :)
}

- (void)didTapReboot:(UITapGestureRecognizer *)gestureRecognizer {

    chosen_strategy.strategy_reboot();
    
}

- (void)didTapClearSpace:(UITapGestureRecognizer *)gestureRecognizer {
    UIViewController *packagesOptionsViewController=[self.storyboard instantiateViewControllerWithIdentifier:@"ClearCacheViewController"];
    packagesOptionsViewController.providesPresentationContextTransitionStyle = YES;
    packagesOptionsViewController.definesPresentationContext = YES;
    [packagesOptionsViewController setModalPresentationStyle:UIModalPresentationOverCurrentContext];
    [self presentViewController:packagesOptionsViewController animated:YES completion:nil];
}

// idea used from Jonathan Levin's tweet: https://twitter.com/Morpheus______/status/942561462450642944
- (IBAction)didToggleDisableSystemUpdatesSwitch:(id)sender {
    
    if (self.disableSystemUpdatesSwitch.on) {
        
        //show_alert(self, @"Feature disabled", @"This feature has been disabled due to some issues with the AppStore");
        [_disableSystemUpdatesSwitch setOn:NO];
        
        //        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"system_updates_disabled"];
        //
        //        // chown Downloads to root
        //        chosen_strategy.strategy_chown("/var/mobile/Media/Downloads", ROOT_UID, WHEEL_GID);
        //        chosen_strategy.strategy_chmod("/var/mobile/Media/Downloads", 000);
        //
        //        // show a warning
        //        show_alert(self, @"Updates Disabled", @"Make sure to delete any downloaded updates in System Preferences → General → iPhone Storage → iOS → Remove. Note: if you have any AppStore issues, disable this option.");
        
    } else {
        
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"system_updates_disabled"];
        
        sleep(1);
        
        // chown Downloads back to mobile
        chosen_strategy.strategy_chown("/var/mobile/Media/Downloads", MOBILE_UID, MOBILE_GID);
        
        chosen_strategy.strategy_chmod("/var/mobile/Media/Downloads", 0755);
        
    }
    
}
- (IBAction)didChangeDisableSystemUpdatesSwitch:(id)sender {
    [self didToggleDisableSystemUpdatesSwitch:sender];
    BOOL c = _disableSystemUpdatesSwitch.on;
    BOOL b = [[NSUserDefaults standardUserDefaults] boolForKey:@"system_updates_disabled"];
    [_disableSystemUpdatesSwitch setOn:b animated:YES];
    if (!c && !b) {
        show_alert(self, @"Feature disabled", @"This feature has been disabled due to some issues with the AppStore");
    }
}

- (IBAction)quickActionsButtonTapped:(id)sender {
    UIViewController *quickActionsViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"QuickActionsView"];
    quickActionsViewController.providesPresentationContextTransitionStyle = YES;
    quickActionsViewController.definesPresentationContext = YES;
    [quickActionsViewController setModalPresentationStyle:UIModalPresentationOverCurrentContext];
    [self presentViewController:quickActionsViewController animated:YES completion:nil];
}

@end
