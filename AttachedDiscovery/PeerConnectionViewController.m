//
//  PeerConnectionViewController.m
//  AttachedDiscovery
//
//  Created by ALBERT AZOUT on 1/6/16.
//  Copyright © 2016 Attached Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PeerConnectionViewController.h"
#import "LLUtility.h"

@interface PeerConnectionViewController ()
@property (strong, nonatomic) NSString *userName;
@property (strong, nonatomic) NSString *peerUsername;
@property (strong, nonatomic) PeerServiceManager *peerServiceManager;
@end

@implementation PeerConnectionViewController

MediaGrabber *mediaGrabber;

- (id)initWithUsername:(NSString *)userName peerUsername:(NSString*)peerUsername {
    self = [super initWithNibName:nil bundle:nil];
    self.userName = userName;
    self.peerUsername = peerUsername;
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.title = self.peerUsername;
    [self addGradientBgLayer:@[[UIColor colorWithHexString:@"4ED8F5"], [UIColor colorWithHexString:@"6C2CFA"]]];
    
    [SVProgressHUD setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:0.10]];
    [SVProgressHUD setForegroundColor:[UIColor whiteColor]];
    [SVProgressHUD setFont:[UIFont fontWithName:@"AvenirNext-Regular" size:12.0f]];
    [SVProgressHUD showWithStatus:@"Waiting for Connection"];
    
    self.peerServiceManager = [[PeerServiceManager alloc] initWithPeerId:self.peerUsername];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pausePeerServiceManager)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(resumePeerServiceManager)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    mediaGrabber = [[MediaGrabber alloc] init];
}

- (void) viewWillDisappear:(BOOL)animated {
    [self pausePeerServiceManager];
    [SVProgressHUD dismiss];
}

- (void) pausePeerServiceManager {
    [self.peerServiceManager stopAdvertising];
    [self.peerServiceManager stopBrowsing];
}

- (void) resumePeerServiceManager {
    [self.peerServiceManager startAdvertising];
    [self.peerServiceManager startBrowsing];
}

// PeerServiceManagerDelegate methods

- (void)connectedDevicesChanged:(PeerServiceManager * __nonnull)manager connectedDevices:(NSArray<NSString *> * __nonnull)connectedDevices {
    for(NSString *displayName in connectedDevices) {
        if(displayName == self.peerUsername) {
            [SVProgressHUD setStatus:@"Connected with Peer"];
            [SVProgressHUD dismiss];
            // send last update date
            NSDate *peerLastMediaUpdateDate = [mediaGrabber getPeerMediaUpdate:self.peerUsername];
            [self.peerServiceManager sendLastMediaDate:peerLastMediaUpdateDate];
        }
    }
}

- (void) receivedData:(PeerServiceManager*)manager data:(NSData*)data {
    //UIImage *image = [UIImage imageWithData:imageData scale:[UIScreen mainScreen].scale];
    NSDictionary *event = (NSDictionary*)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    if(event[@"event"] != nil) {
        int eventType = (int)event[@"event"];
        NSString *timestamp = (NSString*)event[@"timestamp"];
        NSDate *updateDate = [NSDate dateFromISOString:timestamp];
        switch (eventType) {
            case PeerServiceManagerEventTypesEVENT_LAST_MEDIA_DATE:
                NSLog(@"Received lastMediaUpdate date from peer");
                NSArray *assets = [mediaGrabber getPhotosAfterDate_objcAfterTheDate:updateDate];
                if(assets.count > 0) {
                    NSArray *images = [mediaGrabber getImageForAssets:assets];
                    //Now send images
                }
        }
    }
    
}

- (void)peerDiscovered:(PeerServiceManager * __nonnull)manager peerId:(MCPeerID * __nonnull)peerId withDiscoveryInfo:(NSDictionary<NSString *, NSString *> * __nullable)withDiscoveryInfo timestamp:(NSDate * __nonnull)timestamp {
    if(peerId.displayName == self.peerUsername) {
        // Discovered the peer
        [SVProgressHUD setStatus:@"Peer Discovered"];
    }
    
}

@end
