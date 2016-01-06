//
//  UserListViewController.h
//  Discover
//
//  Created by Ömer Faruk Gül on 1/23/14.
//  Copyright (c) 2014 Louvre Digital. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BaseViewController.h"
#import "AttachedDiscovery-Swift.h"
#import <CoreLocation/CoreLocation.h>
#import "Discovery.h"

@interface UserListViewController : BaseViewController <UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate, MediaGrabberDelegate>
- (id)initWithUsername:(NSString *)username userId:(NSString*)userId;
@end
