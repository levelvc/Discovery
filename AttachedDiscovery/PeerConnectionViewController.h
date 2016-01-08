//
//  PeerConnectionViewController.h
//  AttachedDiscovery
//
//  Created by ALBERT AZOUT on 1/6/16.
//  Copyright © 2016 Attached Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BaseViewController.h"
#import "AttachedDiscovery-Swift.h"
#import "SVProgressHUD.h"

@interface PeerConnectionViewController : BaseViewController <PeerServiceManagerDelegate>
- (id)initWithUsername:(NSString *)userName peerUsername:(NSString*)peerUsername;
@end
