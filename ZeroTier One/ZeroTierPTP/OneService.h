//
//  OneService.h
//  ZeroTier One
//
//  Created by Grant Limberg on 10/28/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <ZeroTier/ZeroTier.h>

extern NSString * _Nonnull const statusNotificationKey;
extern NSString * _Nonnull const oneServiceQueueKey;

@class UDPCom;
@class TunTapAdapter;
@class PacketTunnelProvider;

@interface OneService : NSObject <EventHandler, NetworkConfigHandler>
{
    dispatch_queue_t _queue;

    ZeroTierDataStore *_dataStore;
    UDPCom *_udpCom;
    PacketTunnelProvider *_ptp;
    BOOL _isRunning;
    NSMutableDictionary<NSNumber*, VirtualNetworkConfig*> *_configs;
    void (^_runServiceCompletionHandler)(void);
    BOOL _allowDefault;
}

@property (readonly, nonatomic) Node * _Nullable node;
@property (readonly, nonatomic) TunTapAdapter * _Nullable tunTapAdapter;

- (instancetype _Nullable)initWithPTP:(PacketTunnelProvider* _Nonnull)ptp udpCom:(UDPCom * _Nonnull)udpCom;

- (void)runService:(BOOL)allowDefault completionHandler:(nullable void (^)(void))completionHandler;

- (void)stopService;

- (void)onIdentityCollision;

- (void)onEvent:(enum ZT_Event)event;

- (void)onTrace:(NSString * _Nonnull )message;

- (int32_t)onConfigChangedForNetwork:(UInt64)networkId operation:(enum ZT_VirtualNetworkConfigOperation)op config:(VirtualNetworkConfig * _Nonnull)config;

- (void)updateNetworkConfig:(UInt64)nwid config:(VirtualNetworkConfig* _Nonnull)config;

- (void)joinNetwork:(UInt64)networkId;

- (void)leaveNetwork:(UInt64)networkId;

- (UInt64)getDeviceID;

@end
