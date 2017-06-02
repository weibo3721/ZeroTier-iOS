//
//  Node.h
//  ZeroTier One
//
//  Created by Grant Limberg on 1/8/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZeroTierOne.h"
#import "EventHandler.h"
#import "NetworkConfigHandler.h"
#import "NetworkFrameHandler.h"
#import "PacketSender.h"

@class ZeroTierDataStore;
@class NodeStatus;
@class Peer;

UInt64 now();

@interface Node : NSObject
{
    @private
    ZeroTierDataStore *_dataStore;
    id<NetworkConfigHandler> _configHandler;
    id<EventHandler> _eventHandler;
    id<NetworkFrameHandler> _frameHandler;
    id<PacketSender> _packetSender;

    ZT_Node *_node;
    struct ZT_Node_Callbacks *_callbacks;

    UInt64 _nextDeadline;
    NSObject *_deadlineMutex;

    dispatch_once_t _onceToken;
}

- (id) initWithDataStore:(ZeroTierDataStore*)dataStore
           configHandler:(id<NetworkConfigHandler>)configHandler
            eventHandler:(id<EventHandler>)eventHandler
            frameHandler:(id<NetworkFrameHandler>)frameHandler
            packetSender:(id<PacketSender>)packetSender;

- (void)dealloc;

- (void)shutdown;


- (ZeroTierDataStore*)dataStore;
- (id<NetworkConfigHandler>)networkConfigHandler;
- (id<NetworkFrameHandler>)networkFrameHandler;
- (id<EventHandler>)eventHandler;
- (id<PacketSender>)packetSender;

- (void)onMemoryWarning:(NSNotification*)note;

- (UInt64)nextDeadline;
- (void)setNextDeadline:(UInt64)deadline;

- (void)processWirePacket:(const struct sockaddr_storage*)localAddress
            remoteAddress:(const struct sockaddr_storage*)remoteAddress
               packetData:(NSData*)packetData;

- (void)processWirePacket:(const struct sockaddr_storage*)remoteAddress
               packetData:(NSData*)packetData;

- (void)processBackgroundTasks;

- (void)joinNetwork:(UInt64)networkId;

- (void)leaveNetwork:(UInt64)networkId;

- (void)processVirtualNetworkFrameForNetwork:(UInt64)networkId
                                   sourceMac:(UInt64)sourceMac
                                     destMac:(UInt64)destMac
                                   etherType:(UInt32)etherType
                                      vlanId:(UInt32)vlanId
                                   frameData:(NSData*)frameData;

- (void)multicastSubscribe:(UInt64)networkId
            multicastGroup:(UInt64)multicastGroup
              multicastAdi:(UInt32)adi;

- (void)multicastUnsubscribe:(UInt64)networkId
              multicastGroup:(UInt64)multicastGroup
                multicastAdi:(UInt32)adi;

- (UInt64)address;

- (NodeStatus*)status;

- (VirtualNetworkConfig*)networkConfig:(UInt64)networkId;

- (NSArray<Peer*>*)peers;

- (NSArray<VirtualNetworkConfig*>*)networks;

@end
