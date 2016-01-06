//
//  UserListViewController.m
//  Discover
//
//  Created by Ömer Faruk Gül on 1/23/14.
//  Copyright (c) 2014 Louvre Digital. All rights reserved.
//

#import "UserListViewController.h"
#import "BLEUser.h"
#import "LLUtility.h"
#import "Masonry.h"

#define UPDATE_INTERVAL 2.0f

@interface UserListViewController ()
@property (strong, nonatomic) NSString *username;
@property (strong, nonatomic) NSString *userId;
@property (strong, nonatomic) NSArray *users;
@property (strong, nonatomic) UITableView *tableView;
@property (strong, nonatomic) Discovery *discovery;
@property (strong, nonatomic) NSMutableArray *locationQueue;
@property (strong, nonatomic) NSNumber *locationQueueMaxSize;
@end

@implementation UserListViewController

APIRequestManager * requestManager;
User * user;
CLLocationManager *locationManager;
MediaGrabber *mediaGrabber;

- (id)initWithUsername:(NSString *)username userId:(NSString*)userId
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _username = username;
        _userId = userId;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Start location manager
    locationManager = [[CLLocationManager alloc] init];
    locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    locationManager.delegate = self;//or whatever class you have for managing location
    locationManager.pausesLocationUpdatesAutomatically = false;
    [locationManager requestAlwaysAuthorization];
    [locationManager startUpdatingLocation];
        
    requestManager = [[APIRequestManager alloc] initWithApi_key:@"ios_client" host_url:@"http://freestyle-lb-1747063986.us-east-1.elb.amazonaws.com:80"];
    
    dispatch_queue_t userQueue;
    userQueue = dispatch_queue_create("userQueue", nil);
    
    dispatch_async(userQueue, ^{
        user = [requestManager getUser];
        if(user != nil) {
            NSString *firstname = user.firstname;
            self.navigationItem.title = [firstname stringByAppendingString:@"'s Nearby People"];
            self.userId = user.userId;
        } else {
            self.navigationItem.title = @"Nearby People";
        }
    });
	
    [self addGradientBgLayer:@[[UIColor colorWithHexString:@"C93BDF"], [UIColor colorWithHexString:@"2A62E1"]]];
    
    self.users = [NSArray array];
    
    UIView *superview = self.view;
    
    // table view to list nearby users
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.rowHeight = 55;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = [[UIColor whiteColor] colorWithAlphaComponent:0];
    
    if ([self.tableView respondsToSelector:@selector(setSeparatorInset:)]) {
        [self.tableView setSeparatorInset:UIEdgeInsetsZero];
    }
    if ([self.tableView respondsToSelector:@selector(layoutMargins)]) {
        self.tableView.layoutMargins = UIEdgeInsetsZero;
    }
    [self.view addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(superview);
    }];
    
    // create our UUID.
    NSString *uuidStr = @"B9407F30-F5F8-466E-AFF9-25556B57FE99";
    CBUUID *uuid = [CBUUID UUIDWithString:uuidStr];
    
    __weak typeof(self) weakSelf = self;
    
    // start Discovery
    [SVProgressHUD setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:0.10]];
    [SVProgressHUD setForegroundColor:[UIColor whiteColor]];
    [SVProgressHUD setFont:[UIFont fontWithName:@"AvenirNext-Regular" size:12.0f]];
    [SVProgressHUD showWithStatus:@"Scanning for Peers"];
    self.discovery = [[Discovery alloc] initWithUUID:uuid username:self.username usersBlock:^(NSArray *users, BOOL usersChanged) {        
        NSLog(@"Updating table view with users count : %lu %@", (unsigned long)users.count, users);
        weakSelf.users = users;
        [weakSelf.tableView reloadData];
        if(weakSelf.users.count > 0) {
            [SVProgressHUD dismiss];
        } else {
            if(![SVProgressHUD isVisible]) {
                [SVProgressHUD showWithStatus:@"Scanning for Peers"];
            }
        }
    }];
    
    self.locationQueue = [[NSMutableArray alloc] init];
    self.locationQueueMaxSize = [NSNumber numberWithInt:25];
    
    mediaGrabber = [[MediaGrabber alloc] init];
    mediaGrabber.delegate = self;
    [mediaGrabber startCheckingForMedia];

}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [SVProgressHUD dismiss];
    // pause, (it will disable timer and top scanning, but it will continue advertising)
    // this is important, otherwise due to the active timers your VC may not be deallocated.
    [self.discovery setPaused:YES];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // unpause, start timers and scanning
    [self.discovery setPaused:NO];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.users.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"BLEUserCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    // TODO: Change this to compare old date with new date
    BLEUser *bleUser = [self.users objectAtIndex:indexPath.row];
    cell.textLabel.text = bleUser.username;
    
    NSDate *storedUpdate = [mediaGrabber getPeerMediaUpdate:bleUser.username];
    NSDate *currentUpdate = nil;
    if(bleUser.dynamicArray != nil) {
        currentUpdate = bleUser.dynamicArray[0];
    }
    
    BOOL newPhotos = NO;
    if(storedUpdate != nil && currentUpdate != nil) {
        // Compare
        switch ([storedUpdate compare:currentUpdate]) {
            case NSOrderedSame:
                newPhotos = NO;
            default:
                newPhotos = YES;
        }
    }
    [mediaGrabber updatePeerMediaUpdate:bleUser.username updateDate:currentUpdate];
    
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Proximity: %ld   New Photos: %@", (long)bleUser.proximity, newPhotos ? @"Yes" : @"No"];
    
    NSInteger proximity = bleUser.proximity;
    
    UIColor *bgColor;
    
    bgColor = [UIColor whiteColor];
    if (proximity < -85)
        // red
        bgColor = [bgColor colorWithAlphaComponent:0.3];
    else if (proximity < -65)
        // yellow
        bgColor = [bgColor colorWithAlphaComponent:0.4];
    else
        // green
        bgColor = [bgColor colorWithAlphaComponent:0.5];
    
    if ([cell respondsToSelector:@selector(layoutMargins)]) {
        cell.layoutMargins = UIEdgeInsetsZero;
    }
    
    cell.backgroundColor = bgColor;
    cell.contentView.backgroundColor = [UIColor clearColor];
    
    cell.textLabel.font = [UIFont fontWithName:@"AvenirNext-DemiBold" size:15.0f];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.detailTextLabel.font = [UIFont fontWithName:@"AvenirNext-Regular" size:10.0f];
    cell.detailTextLabel.textColor = [UIColor whiteColor];
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"Row selected! %@", indexPath);
    
    BLEUser *bleUser = [self.users objectAtIndex:indexPath.row];
    //[LLUtility showAlertWithTitle:@"Your Friend is not Connected" andMessage:[NSString stringWithFormat:@"Would you like to send a connection notification to %@?", bleUser.username]];
    
    PeerConnectionViewController *vc = [[PeerConnectionViewController alloc] initWithPeerUsername:bleUser.username];
    [self.navigationController pushViewController:vc animated:YES];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    NSLog(@"UserList is deallocated!");
}

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (state == UIApplicationStateBackground || state == UIApplicationStateInactive)
    {
        // Update the media
        [mediaGrabber updateMedia];
        
        //TODO: Update location, with queuing
        if(self.locationQueue.count <= self.locationQueueMaxSize.intValue) {
            [self.locationQueue addObjectsFromArray:[requestManager getLocationUpdate:locations]];
        } else {
            NSLog(@"Sending locations to server %d", (int)self.locationQueue.count);
            // post to server
            [requestManager postLocations:self.locationQueue success:^(void){
                NSLog(@"Locations posted successfully");
            } failure:^(NSError *error){
                NSLog(@"Locations failed to post");
            }];
            [self.locationQueue removeAllObjects];
        }
    }
}

-(void) didReceiveMediaUpdate:(NSArray*)photoAssets latestDate:(NSDate*)latestDate totalPhotoAssets:(NSInteger)totalPhotoAssets {
    NSLog(@"Received new media update: %d", (int)totalPhotoAssets);
    NSArray *mediaArray = @[latestDate.formattedISO8601, @(totalPhotoAssets)];
    // This is where you broadcast your new photos
    [self.discovery updatePeripheralDynamicReadCharacteristic:mediaArray];
}

// Lookup the last timestamp for the peer
- (NSDate*) getPeripheralDynamicCharacteristicArray:(NSString*)username {
    return nil;
}

@end
