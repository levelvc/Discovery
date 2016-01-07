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
@property (strong, nonatomic) NSString *peerUsername;
@end

@implementation PeerConnectionViewController

- (id)initWithPeerUsername:(NSString *)peerUsername {
    self = [super initWithNibName:nil bundle:nil];
    self.peerUsername = peerUsername;
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.title = self.peerUsername;
    [self addGradientBgLayer:@[[UIColor colorWithHexString:@"4ED8F5"], [UIColor colorWithHexString:@"6C2CFA"]]];
}

@end
