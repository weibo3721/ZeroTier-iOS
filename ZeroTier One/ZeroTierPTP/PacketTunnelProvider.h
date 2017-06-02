//
//  PacketTunnelProvider.h
//  ZeroTier One
//
//  Created by Grant Limberg on 10/31/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import <NetworkExtension/NetworkExtension.h>

@class OneService;
@class UDPCom;
@class Reachability;
@class ZeroTierDataStore;

@interface PacketTunnelProvider : NEPacketTunnelProvider
{
    void (^pendingStartCompletion)(NSError * _Nullable);

    OneService *_service;
    ZeroTierDataStore *_dataStore;
    UDPCom *_udpCom;
    Reachability *_reachability;
}

- (void)startTunnelWithOptions:(nullable NSDictionary<NSString *,NSObject *> *)options completionHandler:(void (^ _Nullable)(NSError * _Nullable))completionHandler;
- (void)onNodeStatusChanged:(NSNotification* _Nullable)note;
- (void)errorStartingNode:(NSString* _Nonnull)error;

- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^ _Nullable)(void))completionHandler;

- (void)handleAppMessage:(NSData * _Nonnull)messageData completionHandler:(void (^ _Nullable)(NSData * _Nullable))completionHandler;

- (void)sleepWithCompletionHandler:(void (^ _Nullable)(void))completionHandler;

- (void)wake;

- (NSDictionary<NSString*, id>* _Nonnull)handleNetworkInfoRequest:(UInt64)networkId;

@end
