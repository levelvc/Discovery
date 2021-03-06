//
//  Discovery.m
//  DiscoveryExample
//
//  Created by Ömer Faruk Gül on 08/02/15.
//  Copyright (c) 2015 Ömer Faruk Gül. All rights reserved.
//

#import "Discovery.h"

@interface Discovery()
@property (nonatomic, copy) void (^usersBlock)(NSArray *users, BOOL usersChanged);
@property (strong, nonatomic) NSTimer *timer;
@property (nonatomic) CBMutableCharacteristic *dynamicCharacteristic;
@end

@implementation Discovery

- (instancetype)initWithUUID:(CBUUID *)uuid
                    username:(NSString *)username
                startOption:(DIStartOptions)startOption
                  usersBlock:(void (^)(NSArray *users, BOOL usersChanged))usersBlock {
    self = [super init];
    if(self) {
        _uuid = uuid;
        _username = username;
        _usersBlock = usersBlock;
        
        _paused = NO;
        
        _userTimeoutInterval = 3;
        _updateInterval = 2;
        


        // listen for UIApplicationDidEnterBackgroundNotification
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        
        // listen for UIApplicationDidEnterBackgroundNotification
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        
        
        // we will hold the detected users here
        _usersMap = [NSMutableDictionary dictionary];
        
        // start the central and peripheral managers
        _queue = dispatch_queue_create("com.omerfarukgul.discovery", DISPATCH_QUEUE_SERIAL);
        
        _shouldAdvertise = NO;
        _shouldDiscover = NO;
        
        switch (startOption) {
            case DIStartAdvertisingAndDetecting:
                self.shouldAdvertise = YES;
                _shouldAdvertise = YES;
                self.shouldDiscover = YES;
                _shouldDiscover = YES;
                break;
            case DIStartAdvertisingOnly:
                self.shouldAdvertise = YES;
                _shouldAdvertise = YES;
                break;
            case DIStartDetectingOnly:
                self.shouldDiscover = YES;
                _shouldDiscover = YES;
                break;
            case DIStartNone:
            default:
                break;
        }
    }
    
    return self;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
}

-(void)setShouldAdvertise:(BOOL)shouldAdvertise {
    if(_shouldAdvertise == shouldAdvertise)
        return;
    
    _shouldAdvertise = shouldAdvertise;
    
    if(shouldAdvertise) {
        if (!self.peripheralManager)
            //self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:self.queue];
            // Advertise with restoration key
            self.peripheralManager = [[CBPeripheralManager alloc]
                                      initWithDelegate:self
                                      queue:self.queue
                                      options:@{ CBCentralManagerOptionRestoreIdentifierKey:@"attachedPeripheralManagerIdentifier" }];
    } else {
        if (self.peripheralManager) {
            [self.peripheralManager stopAdvertising];
            self.peripheralManager.delegate = nil;
            self.peripheralManager = nil;
        }
    }
    
    
}

-(void)setShouldDiscover:(BOOL)shouldDiscover {
    if(_shouldDiscover == shouldDiscover)
        return;
    
    _shouldDiscover = shouldDiscover;
    
    if(shouldDiscover) {
        if (!self.centralManager)
            self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:self.queue];
        if (!self.timer)
            [self startTimer];
    } else {
        if (self.centralManager) {
            [self.centralManager stopScan];
            self.centralManager.delegate = nil;
            self.centralManager = nil;
        }
        if (self.timer)
            [self stopTimer];
    }
}

-(instancetype)initWithUUID:(CBUUID *)uuid username:(NSString *)username usersBlock:(void (^)(NSArray *, BOOL))usersBlock {
    self = [self initWithUUID:uuid username:username startOption:DIStartAdvertisingAndDetecting usersBlock:usersBlock];
    return self;
}


- (void)startTimer {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:self.updateInterval target:self
                                                selector:@selector(checkList) userInfo:nil repeats:YES];
}

- (void)stopTimer {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)setUpdateInterval:(NSTimeInterval)updateInterval {
    _updateInterval = updateInterval;
    
    // restart the timers
    [self stopTimer];
    [self startTimer];
}

- (void)setPaused:(BOOL)paused {
    
    NSLog(@"Pausing central manager scanning...");
    
    if(_paused == paused)
        return;
    
    _paused = paused;
    
    if(paused) {
        [self stopTimer];
        [self.centralManager stopScan];
    }
    else {
        [self startTimer];
        [self startDetecting];
    }
}

- (void)appDidEnterBackground:(NSNotification *)notification {
    [self stopTimer];
}

- (void)appWillEnterForeground:(NSNotification *)notification {
    [self startTimer];
}

- (void)startAdvertising {
    
    NSDictionary *advertisingData = @{CBAdvertisementDataLocalNameKey:self.username,
                                      CBAdvertisementDataServiceUUIDsKey:@[self.uuid]
                                      };
    
    // ---------------------------------------------------
    // Username characteristic
    // ---------------------------------------------------
    CBMutableCharacteristic *characteristic =
    [[CBMutableCharacteristic alloc] initWithType:self.uuid
                                       properties:CBCharacteristicPropertyRead
                                            value:[self.username dataUsingEncoding:NSUTF8StringEncoding]
                                      permissions:CBAttributePermissionsReadable];
    
    // ---------------------------------------------------
    // Last Peripheral Photo Update time and count
    // ---------------------------------------------------
    self.dynamicCharacteristic =
    [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:@"8363BECA-88C4-4EFB-9CAB-6815562BCECD"]
                                       properties:CBCharacteristicPropertyRead
                                            value:nil
                                      permissions:CBAttributePermissionsReadable];
    
    // ---------------------------------------------------
    // Last Peripheral Photo Update time and count
    // ---------------------------------------------------
    /*
    CBMutableCharacteristic *centralWriteCharacteristic =
    [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:@"D1E22CBF-C242-46C7-AD08-9FE9CC78C873"]
                                       properties:CBCharacteristicPropertyWriteWithoutResponse
                                            value:nil
                                      permissions:CBAttributePermissionsWriteable];*/

    // create the service with the characteristics
    CBMutableService *service = [[CBMutableService alloc] initWithType:self.uuid primary:YES];
    service.characteristics = @[characteristic, self.dynamicCharacteristic];
    [self.peripheralManager addService:service];
    
    [self.peripheralManager startAdvertising:advertisingData];
}

- (void) updatePeripheralDynamicReadCharacteristic:(NSArray*)arr {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:arr];
    if(self.dynamicCharacteristic != nil) {
        [self.peripheralManager updateValue:data forCharacteristic:self.dynamicCharacteristic onSubscribedCentrals:nil];
        NSLog(@"Updated characteristic value: %@", arr);
    }

}

- (void)startDetecting {
    
    NSDictionary *scanOptions = @{CBCentralManagerScanOptionAllowDuplicatesKey:@(YES)};
    NSArray *services = @[self.uuid];
    
    // we only listen to the service that belongs to our uuid
    // this is important for performance and battery consumption
    [self.centralManager scanForPeripheralsWithServices:services options:scanOptions];
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error {
    NSLog(@"peripheralManager peripheralManagerDidStartAdvertising");
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral willRestoreState:(NSDictionary *)dict {
    NSLog(@"peripheralManager willRestoreState");
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request {
    NSLog(@"peripheralManager didReceiveReadRequest");
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests {
    //NSLog(@"peripheralManager:%@ didReceiveWriteRequests:%@", peripheral, requests);
    NSLog(@"peripheralManager didReceiveWriteRequests");
    CBATTRequest *req = [requests objectAtIndex:0];
    NSString *s = [[NSString alloc] initWithData:req.value encoding:NSUTF8StringEncoding];
    NSLog(@"Got write value %@", s);
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
    NSLog(@"peripheralManager didSubscribeToCharacteristic %@", central.identifier.UUIDString);
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    if(peripheral.state == CBPeripheralManagerStatePoweredOn) {
        [self startAdvertising];
    }
    else {
        //NSLog(@"Peripheral manager state: %d", peripheral.state);
    }
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn) {
        [self startDetecting];
    }
    else {
        NSLog(@"Central manager state: %d", (int)central.state);
    }
}

- (void)updateList {
    [self updateList:YES];
}

- (void)updateList:(BOOL)usersChanged {
    
    NSMutableArray *users;
    
    @synchronized(self.usersMap) {
        users = [[[self usersMap] allValues] mutableCopy];
    }
    
    // remove unidentified users
    NSMutableArray *discardedItems = [NSMutableArray array];
    for (BLEUser *user in users) {
        if (!user.isIdentified)
            [discardedItems addObject:user];
    }
    [users removeObjectsInArray:discardedItems];
    
    // we sort the list according to "proximity".
    // so the client will receive ordered users according to the proximity.
    [users sortUsingDescriptors: [NSArray arrayWithObjects: [NSSortDescriptor sortDescriptorWithKey:@"proximity"
                                                                                          ascending:NO], nil]];
    if(self.usersBlock) {
        self.usersBlock([users mutableCopy], usersChanged);
    }
}

- (void)checkList {
    
    double currentTime = [[NSDate date] timeIntervalSince1970];
    
    NSMutableArray *discardedKeys = [NSMutableArray array];
    
    for (NSString* key in self.usersMap) {
        BLEUser *bleUser = [self.usersMap objectForKey:key];
        
        NSTimeInterval diff = currentTime - bleUser.updateTime;
        
        // We remove the user if we haven't seen him for the userTimeInterval amount of seconds.
        // You can simply set the userTimeInterval variable anything you want.
        if(diff > self.userTimeoutInterval) {
            [discardedKeys addObject:key];
        }
    }
    
    // update the list if we removed a user.
    if(discardedKeys.count > 0) {
        [self.usersMap removeObjectsForKeys:discardedKeys];
        [self updateList];
    }
    else {
        // simply update the list, because the order of the users may have changed.
        [self updateList:NO];
    }
}

- (BLEUser *)userWithPeripheralId:(NSString *)peripheralId {
    return [self.usersMap valueForKey:peripheralId];
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    //NSLog(@"User is discovered: %@ %@ at %@", peripheral.name, peripheral.identifier, RSSI);
    
    NSString *username = advertisementData[CBAdvertisementDataLocalNameKey];

    //NSLog(@"Discovered name : %@", username);
    
    BLEUser *bleUser = [self userWithPeripheralId:peripheral.identifier.UUIDString];
    if(bleUser == nil) {
        //NSLog(@"Adding ble user: %@", name);
        bleUser = [[BLEUser alloc] initWithPerpipheral:peripheral];
        bleUser.username = nil;
        bleUser.identified = NO;
        bleUser.peripheral.delegate = self;
        bleUser.dynamicArray = nil;
        
        /*
        NSData *dynamicVal = [self.dynamicReadCharacteristic value];
        if(dynamicVal != nil) {
            NSArray *array = [NSKeyedUnarchiver unarchiveObjectWithData:dynamicVal];
            bleUser.dynamicArray = array;
        }*/
    
        [self.usersMap setObject:bleUser forKey:bleUser.peripheralId];
    }
    
    //NSLog(@"BLUEUser is identified %d", bleUser.isIdentified);
    if(!bleUser.isIdentified) {
        // We check if we can get the username from the advertisement data,
        // in case the advertising peer application is working at foreground
        // if we get the name from advertisement we don't have to establish a peripheral connection
        if (username != (id)[NSNull null] && username.length > 0 ) {
            bleUser.username = username;
            bleUser.identified = YES;
            
            // we update our list for callback block
            [self updateList];
        }
        else {
            // nope we could not get the username from CBAdvertisementDataLocalNameKey,
            // we have to connect to the peripheral and try to get the characteristic data
            // add we will extract the username from characteristics.
            
            NSLog(@"Connecting to peripheral (background)!");
            
            if(peripheral.state == CBPeripheralStateDisconnected) {
                [self.centralManager connectPeripheral:peripheral options:nil];
            }
        }
    }
    
    // update the rss and update time
    bleUser.rssi = [RSSI floatValue];
    bleUser.updateTime = [[NSDate date] timeIntervalSince1970];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Peripheral connection failure: %@. (%@)", peripheral, [error localizedDescription]);
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    BLEUser *user = [self userWithPeripheralId:peripheral.identifier.UUIDString];
    NSLog(@"Peripheral Connected: %@", user);
    
    // Search only for services that match our UUID
    // the connection does not guarantee that we will discover the services.
    // if the device is too far away, it may not be possible to discover the service we want.
    [peripheral discoverServices:@[self.uuid]];
}


#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    // loop the services
    // since we are looking forn only one service, services array probably contains only one or zero item
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSLog(@"Did discover characteristics of: %@", service.characteristics);
    
    if (!error) {
        // loop through to find our characteristic
        for (CBCharacteristic *characteristic in service.characteristics) {
            // This is the peripheral username characteristic
            if([characteristic.UUID isEqual:self.uuid]) {
                [peripheral readValueForCharacteristic:characteristic];
            }
            // This is the peripheral last media update information
            if([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"8363BECA-88C4-4EFB-9CAB-6815562BCECD"]]) {
                NSLog(@"Reading dynamic characteristic!");
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            }
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if([characteristic.UUID isEqual:self.uuid]) {
        NSString *valueStr = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        NSLog(@"CBCharacteristic updated value: %@", valueStr);
        
        // if the value is not nil, we found our username!
        if(valueStr != nil) {
            BLEUser *user = [self userWithPeripheralId:peripheral.identifier.UUIDString];
            user.username = valueStr;
            user.identified = YES;
            
            [self updateList];
            
            // cancel the subscription to our characteristic
            [peripheral setNotifyValue:NO forCharacteristic:characteristic];
            
            // and disconnect from the peripehral
            [self.centralManager cancelPeripheralConnection:peripheral];
        }
    } else if([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"8363BECA-88C4-4EFB-9CAB-6815562BCECD"]]) {
        NSArray *array = [NSKeyedUnarchiver unarchiveObjectWithData:characteristic.value];
        if(array != nil) {
            NSLog(@"Dynamic value updated %@", array);
            BLEUser *bleUser = [self userWithPeripheralId:peripheral.identifier.UUIDString];
            NSMutableArray *storeArray = [[NSMutableArray alloc] init];
            [storeArray addObject:[NSDate dateFromISOString:array[0]]];
            [storeArray addObject:array[1]];
            if(bleUser != nil) {
                bleUser.dynamicArray = storeArray;
                [self.usersMap setObject:bleUser forKey:bleUser.peripheralId];
                [self updateList];
            }
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"Characteristic Update Notification: %@", error);
}

@end
