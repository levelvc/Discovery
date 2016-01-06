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
    [self addGradientBgLayer:@[[UIColor colorWithHexString:@"C93BDF"], [UIColor colorWithHexString:@"2A62E1"]]];
}

@end
