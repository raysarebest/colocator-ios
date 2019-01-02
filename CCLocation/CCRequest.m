//
//  CCRequest.m
//  CCLocation
//
//  Created by Ralf Kernchen on 12/04/2014.
//  Copyright (c) 2014 CrowdConnected. All rights reserved.
//

#import "CCRequest.h"
#import <SocketRocket/SRWebSocket.h>
#import <CCLocation/CCLocation-Swift.h>
#import "CCiBeacon.h"
#import "CCBLE.h"
#import "CCGPS.h"
#import "UUIDHelper.h"
#import <UIKit/UIKit.h>
#import "CCReachabilityManager.h"
#import "Cycler.h"
#import "NSMutableArray+LIFO_Queue.h"

@import TrueTime;

#include <sys/types.h>
#include <sys/sysctl.h>


#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

//static NSInteger const DEFAULT_PING_DELAY = 5 * 60 * 1000;
static NSInteger const MIN_DELAY = 1 * 1000;
static NSInteger const MAX_DELAY = 60 * 60 * 1000;
static NSInteger const MAX_CYCLE_DELAY = 24 * 60 * 60 * 1000;
static NSString* const WS_PREFIX = @"wss://";
static NSString* const LAST_DEVICE_ID_KEY = @"LastDeviceId";
static NSString* const ALIAS_KEY = @"Aliases";
//static NSInteger const STD_CACHE_PACKAGE_SIZE = 10;

@interface CCRequest () <CCBLEDelegate, SRWebSocketDelegate, CCLocationManagerDelegate, NSURLSessionDelegate>

//@property (nonatomic) CCiBeacon* cciBeacon;
@property (nonatomic) SRWebSocket* webSocket;
//@property (nonatomic) CCBLE* ccBLE;
//@property (nonatomic) CCGPS* ccGPS;
//@property (nonatomic) Cycler* cycler;
@property (nonatomic) NSString* ccServerURLString;
@property (nonatomic) NSString* ccAPIKeyString;
@property (nonatomic) NSString* ccWebsocketBaseURL;
@property (nonatomic) NSTimer* reconnectTimer;
@property (nonatomic) NSTimer* maxCycleTimer;
@property (nonatomic) NSTimer* pingTimer;
@property (nonatomic) NSString* deviceId;
//@property (nonatomic) NSMutableArray<ClientMessage*>* messageQueue;
@property (nonatomic) CCRequestMessaging* ccRequestMessaging;
@property (nonatomic) CCLocationManager* ccLocationManager;
@property (nonatomic) CCSocket* ccSocket;
@property (nonatomic) TrueTimeClient* timeClient;
//@property NSInteger pingTimerDelay;
//@property NSInteger cachePackageSize;
@property NSInteger delay;
@property BOOL running;
@property BOOL firstReconnect;
@property BOOL isDatabaseOpen;
@property BOOL isFetchingTrueTime;

@end

//#ifdef DEBUG
////    static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//    static const DDLogLevel ddLogLevel = DDLogLevelWarning;
//#else
//    static const DDLogLevel ddLogLevel = DDLogLevelWarning;
//#endif

@implementation CCRequest

+ (id)sharedManager {
    static CCRequest *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[CCRequest alloc] init];
    });
    return sharedMyManager;
}

- (id) init {
    if (self = [super init]) {

//        [self createOrOpenDatabase];
        
//        CCCocoaLumberFormatter* lumberFormatter = [[CCCocoaLumberFormatter alloc] init];
//        DDTTYLogger* ttylogger = [DDTTYLogger sharedInstance];
//        [ttylogger setLogFormatter:lumberFormatter];

//        DDASLLogger* ddasLogger = [DDASLLogger sharedInstance];
//        [ddasLogger setLogFormatter:lumberFormatter];
//        [DDLog addLogger:ddasLogger];

        _timeClient = [[TrueTimeClient alloc] initWithTimeout:8 maxRetries:10 maxConnections:5 maxServers:5 numberOfSamples:4 pollInterval:3600];
//        [_timeClient startWithHostURLs:@[[NSURL URLWithString:@"time.apple.com"]]];

        self.running = NO;
//        self.cachePackageSize = STD_CACHE_PACKAGE_SIZE;
//        self.messageQueue = [[NSMutableArray<ClientMessage*> alloc] initWithMaxLIFOSize:MAX_QUEUE_SIZE];

        self.reconnectTimer = nil;
        self.maxCycleTimer = nil;
        self.pingTimer = nil;
        self.firstReconnect = YES;
        self.isFetchingTrueTime = NO;
        
        self.ccSocket = [[CCSocket alloc] init];
//        self.pingTimerDelay = DEFAULT_PING_DELAY;
//        DDLogWarn(@"Instantiated Colocator Framework");
    }
    return self;
}

- (void) startWithURLString:(NSString*) serverURL
                     apiKey:(NSString*) apiKey
         ccRequestMessaging:(CCRequestMessaging*) ccRequestMessaging
          ccLocationManager:(CCLocationManager*) ccLocationManager
{
    if(!self.running){
        
        self.running = YES;
        
        self.startTime = [NSDate date];
        
        // read last stored device id from user defaults, if first install and not device id was stored, device id will be nil
        self.deviceId = [[NSUserDefaults standardUserDefaults] stringForKey:LAST_DEVICE_ID_KEY];
        
        // initialize BT cycling
//        self.cycler = [[Cycler alloc] init];
        
        self.ccServerURLString = serverURL;
        self.ccAPIKeyString = apiKey;
        
        self.ccWebsocketBaseURL = [WS_PREFIX stringByAppendingFormat:@"%@/%@", serverURL, apiKey];
        
        [CCReachabilityManager sharedManager];
        
        self.ccLocationManager = ccLocationManager;
        self.ccLocationManager.delegate = self;
        
        self.ccRequestMessaging = ccRequestMessaging;
        
//        // initialise CCiBeacon
//        self.cciBeacon = [[CCiBeacon alloc] init];
//        self.cciBeacon.delegate = self;
//        
//        // initialise CCBLE
//        self.ccBLE = [[CCBLE alloc] init];
//        self.ccBLE.delegate = self;
//        
//        // iniitialise CCGPS
//        self.ccGPS = [[CCGPS alloc] init];
//        self.ccGPS.delegate = self;
        
        NSLog(@"Started Colocator Framework");
        
        [self connect:nil];

    } else {
        [self stop];
        [self startWithURLString:serverURL apiKey:apiKey ccRequestMessaging:ccRequestMessaging ccLocationManager:ccLocationManager];
    }
}

- (void) stop {
    if (self.running){
        self.running = NO;
        
//        [self.cycler stopCycling];
//        self.cycler = nil;
        
        //shutdown websocket
        self.webSocket.delegate = nil;
        self.webSocket = nil;
        
        // shutdown CCLocationManager
        self.ccLocationManager.delegate = nil;
        self.ccLocationManager = nil;
        
        // shutdown CCRequestManager
        self.ccRequestMessaging = nil;
        
        // shutdown CCiBeacon
//        self.cciBeacon.delegate = nil;
//        self.cciBeacon = nil;
        
        // shutdown CCBLE
//        self.ccBLE.delegate = nil;
//        self.ccBLE = nil;
        
        // shutdown CCGPS
//        self.ccGPS.delegate = nil;
//        self.ccGPS = nil;
        
        //deleted the reconnect timer
        [self.reconnectTimer invalidate];
        self.reconnectTimer = nil;
        
        //delete the max cycle timer
        [self.maxCycleTimer invalidate];
        self.maxCycleTimer = nil;
        
        //delete ping timer
        [self.pingTimer invalidate];
        self.pingTimer = nil;
        
        self.ccServerURLString = nil;
        self.ccAPIKeyString = nil;
        self.ccWebsocketBaseURL = nil;
        self.startTime = nil;
        
        NSLog(@"[Colocator] Stopping Colocator");
    }
}

- (void)sendMarker:(NSString *)data{
    
//    [self.cycler stopCycling];

    [self.ccRequestMessaging processMarkerWithData:data];

//    [self.cycler startCycling];
}

- (void)connect:(NSTimer*) timer{
    NSLog(@"[Colocator] Establishing connection to Colocator servers ...");
    
    // first time connect
    if (!timer){
//        DDLogDebug(@"first connect");
    // timer based connect
    } else {
//        DDLogDebug(@"Timer fired");
    }
    
    if (!self.webSocket) {
        // initialise websocket
        NSMutableURLRequest *platformConnectionRequest = [NSMutableURLRequest requestWithURL: [_ccSocket socketURLWithUrl:self.ccWebsocketBaseURL id:self.deviceId]];
//        NSMutableURLRequest *platformConnectionRequest = [NSMutableURLRequest requestWithURL:[self socketURL:self.ccWebsocketBaseURL id:self.deviceId]];
        
        NSString *cerPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"certificate" ofType:@"der"];
        NSData *certData = [[NSData alloc] initWithContentsOfFile:cerPath];
        CFDataRef certDataRef = (__bridge CFDataRef)certData;
        SecCertificateRef certRef = SecCertificateCreateWithData(NULL, certDataRef);
        id certificate = (__bridge id)certRef;
        [platformConnectionRequest setSR_SSLPinnedCertificates:@[certificate]];
        
        if (!platformConnectionRequest.URL){
            NSLog(@"[Colocator] Construction of the platform connection request URL failed, will not attempt to connect to CoLocator backend");
        } else {
            self.webSocket = [[SRWebSocket alloc] initWithURLRequest:platformConnectionRequest];
            self.webSocket.delegate = self;
        }
    }
    [self.webSocket open];
}

- (void)stopCycler:(NSTimer*) timer{
//    DDLogVerbose(@"stop cycling in CCRequest");
    [_ccLocationManager stopAllLocationObservations];
    self.maxCycleTimer = nil;
}

- (void)delayedReconnect {
    
    if (self.delay == 0){
        self.delay = MIN_DELAY;
    }
    
    if (self.pingTimer){
        [self.pingTimer invalidate];
    }
    
//    DDLogDebug(@"delay for reconnect is: %ld", (long)self.delay / 1000);
    
    self.reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:self.delay / 1000 target:self selector:@selector(connect:) userInfo:nil repeats:NO];
    
    if (self.delay * 1.2 < MAX_DELAY) {
        self.delay = self.delay * 1.2;
    } else {
        self.delay = MAX_DELAY;
    }
    
    if (self.maxCycleTimer == nil && self.firstReconnect){
//        DDLogVerbose(@"max cycle timer == nil");
//        [self.cycler setOnlineState:NO];
        self.maxCycleTimer = [NSTimer scheduledTimerWithTimeInterval:MAX_CYCLE_DELAY / 1000 target:self selector:@selector(stopCycler:) userInfo:nil repeats:NO];
    }
    
    self.firstReconnect = NO;
}

- (void) setAliases:(NSDictionary*)aliases {
    if (aliases != nil){
        _aliases = aliases;
        [[NSUserDefaults standardUserDefaults] setObject:_aliases forKey:ALIAS_KEY];
        [self.ccRequestMessaging processAliasesWithAliases:_aliases];
    }
}

- (void) setDeviceIdSwiftBridge:(NSString *)deviceId {
    self.deviceId = deviceId;
    
    // persisting the device id
    [[NSUserDefaults standardUserDefaults] setObject:self.deviceId forKey:LAST_DEVICE_ID_KEY];
    
//    DDLogVerbose(@"DEVICE_ID is: %@", self.deviceId);
}

//- (void) messageQueuePushSwiftBridge:(NSData*) message {

    
//    [self.messageQueue push:clientMessage];
    
//    [self storeToDatabase:message];
//}

- (void) fetchTrueTime {
    
//    DDLogDebug(@"fetchTrueTime %d", _isFetchingTrueTime);

    if (!_isFetchingTrueTime) {

        _isFetchingTrueTime = YES;
        // To block waiting for fetch, use the following:
        [_timeClient fetchIfNeededWithSuccess:^(NTPReferenceTime *referenceTime) {
            NSLog(@"[Colocator] True time: %@", [referenceTime now]);
            
            NSDate *lastRebootTime = [[referenceTime now] dateByAddingTimeInterval:-[self timeIntervalSinceBoot]];
            
            [self.ccRequestMessaging newTrueTimeAvailableWithTrueTime:[referenceTime now] timeIntervalSinceBootTime:[self timeIntervalSinceBoot] systemTime:[NSDate date] lastRebootTime:lastRebootTime];
            
            _isFetchingTrueTime = NO;
            
        } failure:^(NSError *error) {
            NSLog(@"[Colocator] Truetime error! %@", error);
            
            _isFetchingTrueTime = NO;
        }];
    }
}

//- (long) getCachePackageSizeSwiftBridge {
//    return self.cachePackageSize;
//}

//- (void) setCachePackageSizeSwiftBridge:(NSInteger)cachePackageSize{
//    self.cachePackageSize = cachePackageSize;
//}

//- (long) getTimeBetweenSendsSwiftBrigde {
//    return self.timeBetweenSends;
//}
//
//- (void) setTimeBetweenSendsSwiftBridge:(NSInteger)timeInMilliseconds{
//    self.timeBetweenSends = timeInMilliseconds;
//}

//- (void) setPingTimerDelaySwiftBridge:(NSInteger)pingTimerDelay {
//    self.pingTimerDelay = pingTimerDelay;
//}

//- (void) resetPingTimerSwiftBridge{
//    if (self.pingTimer){
//        [self.pingTimer invalidate];
//        self.pingTimer = [NSTimer scheduledTimerWithTimeInterval:self.pingTimerDelay / 1000 target:self selector:@selector(sendPing:) userInfo:nil repeats:YES];
//    }
//}

- (void) updateBTSettingsSwiftBridge:(NSNumber*)btleAltBeaconScanTime btleBeaconScanTime:(NSNumber*)btleBeaconScanTime btleAdvertiseTime:(NSNumber*)btleAdvertiseTime idleTime:(NSNumber*)idleTime offTime:(NSNumber*)offTime altBeaconScan:(BOOL)altBeaconScan batchWindow:(NSNumber*)batchWindow state:(NSString*)state {
//    [self.cycler updateBTSettings:btleAltBeaconScanTime btleBeaconScanTime:btleBeaconScanTime btleAdvertiseTime:btleAdvertiseTime idleTime:idleTime offTime:offTime altBeaconScan:altBeaconScan batchWindow:batchWindow state:state];
}

- (void) updateGEOSettingsSwiftBridge:(BOOL) network gps:(BOOL)gps cycleOn:(NSInteger)cycleOn cycleOff:(NSInteger)cycleOff interval:(NSInteger)interval minDistance:(NSInteger)minDistance accuracy:(float)accuracy regions:(NSArray*)regions{

//    [self.ccLocationManager switchSignificatLocationChangesOn:network];
    
//    [self.ccGPS updateSettings:network gps:gps cycleOn:cycleOn cycleOff:cycleOff interval:interval minDistance:minDistance accuracy:accuracy regions:regions];
}

- (void)setiBeaconProximityUUIDsSwiftBridge:(NSArray *)proximitUUIDs {
//    [self.cciBeacon setiBeaconProximityUUIDs:proximitUUIDs];
//    [self.ccLocationManager setBeaconRegionsWithUuids:proximitUUIDs];
}

- (NSDate*)getStartTimeSwiftBridge{
    return self.startTime;
}

- (NSTimeInterval) timeIntervalSinceBoot {
    // TODO: Potentially a race condition if the system clock changes between reading `bootTime` and `now`
    int status;
    
    struct timeval bootTime;
    status = sysctl((int[]){CTL_KERN, KERN_BOOTTIME}, 2,
                    &bootTime, &(size_t){sizeof(bootTime)},
                    NULL, 0);
    NSCAssert(status == 0, nil);
    
    struct timeval now;
    status = gettimeofday(&now, NULL);
    NSCAssert(status == 0, nil);
    
    struct timeval difference;
    timersub(&now, &bootTime, &difference);
    
    return (difference.tv_sec + difference.tv_usec * 1.e-6);
}

#pragma mark - SRWebSocketDelegate

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    NSLog(@"[Colocator] ... connection to back-end established");

    [self.ccRequestMessaging webSocketDidOpen];

//    if (!self.pingTimer){
//        self.pingTimer = [NSTimer scheduledTimerWithTimeInterval:self.pingTimerDelay / 1000 target:self selector:@selector(sendPing:) userInfo:nil repeats:YES];
//    } else {
//        DDLogVerbose(@"We've got an existing ping timer, not issuing a new timer again");
//    }
    
    self.delay = MIN_DELAY;
    
    // read last stored aliases from user defaults
    NSDictionary* aliases = [[NSUserDefaults standardUserDefaults] dictionaryForKey:ALIAS_KEY];

    if (aliases != nil){
        [self.ccRequestMessaging processAliasesWithAliases:aliases];
    }
        
    //delete the max cycle timer
    [self.maxCycleTimer invalidate];
    self.maxCycleTimer = nil;
    
    self.firstReconnect = YES;
    
//    [self.cycler setOnlineState:YES];
    
    [self.delegate ccRequestDidConnect];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    NSLog(@"[Colocator] :( Connection failed With Error %@", error.description);
    
    self.webSocket = nil;
    self.webSocket.delegate = nil;
    
    [self.ccRequestMessaging webSocketDidClose];
    [self.delegate ccRequestDidFailWithError:[NSError errorWithDomain:@"com.crowdconnected.CCLocation" code:-1 userInfo:nil]];
    
    [self delayedReconnect];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
//    DDLogVerbose(@"Did Receive Message from Websocket: \"%@\"", message);
    
    NSData *message_data;
    
    if ([message isKindOfClass:[NSString class]]) {
//        DDLogVerbose(@"Received text message");
        message_data = [message dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([message isKindOfClass:[NSData class]]) {
//        DDLogVerbose(@"Received binary message");
        message_data = message;
        
        [self.ccRequestMessaging processServerMessageWithData:message_data error: nil];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
//    DDLogVerbose(@"WebSocket closed with code: %ld , reason: %@, was clean: %@", (long)code, reason, wasClean ? @"YES" : @"NO");
    
    self.webSocket = nil;
    self.webSocket.delegate = nil;
    
    [self delayedReconnect];
}

#pragma mark - CCiBeacon delegate method

- (void) receivediBeaconInfoWithProximityUUID:(NSUUID *)proximityUUID major:(NSInteger)major minor:(NSInteger)minor proximity:(NSInteger)proximity accuracy:(double)accuracy rssi:(NSInteger)rssi timestamp:(NSTimeInterval)timestamp{
//    DDLogVerbose(@"Beacon information is: Proximity UUID: %@ Beacon major: %ld Beacon minor: %ld Beacon accuracy: %f RSSI: %i", proximityUUID.UUIDString, (long)major, (long)minor, accuracy, (int)rssi);
    
//    NSTimeInterval timeIntervalSinceStartTime = [[NSDate date] timeIntervalSinceDate:self.startTime];
    
    [self.ccRequestMessaging processIBeaconEventWithUuid:proximityUUID
                                                  major:major
                                                  minor:minor
                                                   rssi:rssi
                                               accuracy:accuracy
                                              proximity:proximity
                                              timestamp:timestamp];
}

#pragma mark - CCBLE delegate method

-(void) receivedPeripheralInfo: (NSString*)name advertisementData:(NSDictionary*)advertisementData RSSI:(NSNumber*)RSSI timestamp:(NSDate *)timestamp{
    
//    DDLogVerbose(@"uuidbase64 String is: %@", [name stringByReplacingOccurrencesOfString:@"ccid" withString:@""]);
    
    NSTimeInterval timeIntervalSinceStartTime = [timestamp timeIntervalSinceDate:self.startTime];
    
    NSUUID *peripheralUUID = [UUIDHelper UUIDFromBase64String:[name stringByReplacingOccurrencesOfString:@"ccid" withString:@""]];
    
//    DDLogVerbose(@"Time interval for bluetooth peripheral discovery: %f", timeIntervalSinceStartTime);
    
    [self.ccRequestMessaging processBluetoothEventWithUuid:peripheralUUID
                                                     rssi:RSSI.intValue
                                             timeInterval:timeIntervalSinceStartTime];
}

-(void) receivedCollatedAltBeaconsInfo:(NSDictionary *)devices timestamp:(NSDate *)timestamp{
    
    //    DDLogVerbose(@"uuidbase64 String is: %@", [name stringByReplacingOccurrencesOfString:@"ccid" withString:@""]);
    //
    
//    NSUUID *peripheralUUID = [UUIDHelper UUIDFromBase64String:[name stringByReplacingOccurrencesOfString:@"ccid" withString:@""]];
    
//    DDLogVerbose(@"time interval for bluetooth discovery: %f", [timestamp timeIntervalSinceDate:self.startTime]);
    
    //    [self sendCollatedBluetoothMessage:devices timeIntervalSinceAppStart:[timestamp timeIntervalSinceDate: self.startTime]];
}

#pragma mark - a send client message function that handles queuing of messages when offline
//- (void) sendClientMessage: (NSData* ) clientMessageData queuable:(BOOL)queuable{
//    // making sure that we are not sending when the connection is not open, otherwise app terminates
//    if (self.webSocket.readyState == SR_OPEN) {
//        DDLogVerbose(@"Websocket is open sending messages");
//        [self.ccRequestMessaging sendQueuedClientMessagesWithFirstMessage:clientMessageData];
//    } else if (queuable) {
//        DDLogVerbose(@"Websocket is NOT open, message is queuable");
//        [self.messageQueue push:clientMessageData];
//    }
//}

//- (void) sendPing:(NSTimer*) timer {
//    [self.ccRequestMessaging sendPing];
//}

- (void) sendWebSocketMessageSwiftBridge:(NSData*) data{
    [self.webSocket send:data];
}

#pragma mark - proximity translation method

- (int)numberForProximity:(CLProximity)proximity {
    switch (proximity) {
        case CLProximityUnknown:
            return 4;
            break;
        case CLProximityImmediate:
            return 3;
            break;
        case CLProximityNear:
            return 2;
            break;
        case CLProximityFar:
            return 1;
            break;
    }
}

//#pragma mark - create socket URL

//#pragma mark - getters for current network, device type and library version


//# pragma mark - detect iOS platform

- (void) dealloc {
    self.timeClient = nil;
}

@end

