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
UICollectionView *collectionView;
NSMutableArray *photos;

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
    photos = [[NSMutableArray alloc] init];
    
    //Setup collection view
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.sectionInset = UIEdgeInsetsMake(0, 0, 0, 0);

    collectionView=[[UICollectionView alloc] initWithFrame:self.view.frame collectionViewLayout:layout];
    [collectionView setDataSource:self];
    [collectionView setDelegate:self];
    
    [collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"cellIdentifier"];
    [collectionView setBackgroundColor:self.view.backgroundColor];
    
    [self.view addSubview:collectionView];
    
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
            [self.peerServiceManager sendLastMediaDate:peerLastMediaUpdateDate peerId:self.peerUsername];
        }
    }
}

- (void) receivedData:(PeerServiceManager*)manager data:(NSData*)data {
    //UIImage *image = [UIImage imageWithData:imageData scale:[UIScreen mainScreen].scale];
    NSDictionary *event = (NSDictionary*)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    if(event[@"event"] != nil) {
        int eventType = (int)event[@"event"];
        NSString *timestamp = (NSString*)event[@"timestamp"];
        if(eventType == PeerServiceManagerEventTypesEVENT_LAST_MEDIA_DATE) {
            NSDate *updateDate = [NSDate dateFromISOString:timestamp];
            NSLog(@"Received lastMediaUpdate date from peer");
            NSArray *assets = [mediaGrabber getPhotosAfterDate_objcAfterTheDate:updateDate];
            if(assets.count > 0) {
                NSArray *images = [mediaGrabber getImageForAssets:assets];
                //Now send images asynchronously
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    for(UIImage *image in images) {
                        [self.peerServiceManager sendImage:image peerId:self.peerUsername];
                    }
                });
            }
        }
        else if (eventType == PeerServiceManagerEventTypesEVENT_IMAGE) {
            //Received image, do something with interface
            NSLog(@"Received Image");
            UIImage *image = [UIImage imageWithData:event[@"data"] scale:[UIScreen mainScreen].scale];
            [photos addObject:image];
        }
    }
}

- (void)peerDiscovered:(PeerServiceManager * __nonnull)manager peerId:(MCPeerID * __nonnull)peerId withDiscoveryInfo:(NSDictionary<NSString *, NSString *> * __nullable)withDiscoveryInfo timestamp:(NSDate * __nonnull)timestamp {
    if(peerId.displayName == self.peerUsername) {
        // Discovered the peer
        [SVProgressHUD setStatus:@"Peer Discovered"];
    }
    
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return photos.count;
}

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell=[collectionView dequeueReusableCellWithReuseIdentifier:@"cellIdentifier" forIndexPath:indexPath];
    UIImageView *imageView = (UIImageView *)[cell viewWithTag:100];
    imageView.image = [UIImage imageNamed:[photos objectAtIndex:indexPath.row]];
    [self.view addSubview:imageView];
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    //return CGSizeMake(100, 100);
    NSLog(@"collectionView.frame.size.width = %d", (int)collectionView.frame.size.width);
    return CGSizeMake(collectionView.frame.size.width/3 - 7, 100);
    
}
- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section{
    return UIEdgeInsetsMake(0, 0, 0, 0);
}

@end
