//
//  TunTapAdapter.h
//  ZeroTier One
//
//  Created by Grant Limberg on 10/28/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import <ZeroTier/NetworkFrameHandler.h>
#import <Foundation/Foundation.h>

typedef void ARP;
typedef uint64_t NetworkID;

enum PackatType {
    ARP_PACKET = 0x0806,
    IPV4_PACKET = 0x0800,
    IPV6_PACKET = 0x86dd
};

static const UInt8 IPV6_ICMPV6 = 0x3a;

@class Node;
@class PacketTunnelProvider;
@class NDPTable;
@class Route;

@interface TunTapAdapter : NSObject <NetworkFrameHandler>
{
    Node *_node;
    PacketTunnelProvider *_ptp;
    ARP *_arpTable;
    NDPTable *_ndTable;

    NSObject *_routeMutex;
    NSMutableDictionary<Route *, NSNumber*> *_routeMap;
}


- (instancetype)initWithPTP:(PacketTunnelProvider*)ptp;

- (void)setNode:(Node*)node;
- (void)setLocalArpInfo:(UInt32)address mac:(UInt64)mac;
- (void)start;

- (void)handleIncomingPackets:(NSArray<NSData*>*)packets protocols:(NSArray<NSNumber*>*)protocols;

- (void)handleIPv4Packet:(NSData*)packet;
- (void)handleIPv6Packet:(NSData*)packet;
- (void)handleUnknownPacket:(NSData*)packet;

- (NSString*)uint64ToHex:(UInt64)value;

- (void)onVirtualNetworkFrameFromNetwork:(UInt64)networkId sourceMac:(UInt64)sourceMac destMac:(UInt64)destMac etherType:(uint32_t)etherType vlanId:(uint32_t)vlanId data:(NSData *)data;

- (void)onARPFrameReceived:(UInt64)networkId sourceMac:(UInt64)sourceMac destMac:(UInt64)destMac data:(NSData*)data;
- (void)onIPv4FrameReceived:(NSData*)data;
- (void)onIPv6FrameReceived:(UInt64)networkId sourceMac:(UInt64)sourceMac destMac:(UInt64)destMac data:(NSData*)data;

- (BOOL)isNeighborSolicitation:(NSData*)packet;
- (BOOL)isNeighborAdvertisement:(NSData*)packet;
- (BOOL)isNeighborDiscovery:(NSData*)packet;

- (void)addRouteAndNetwork:(Route*)route nwid:(UInt64)network;

- (void)clearRouteMap;

- (UInt64)networkIdForDestination:(struct sockaddr_storage)dest;
- (Route*)routeForDestination:(struct sockaddr_storage)dest;


@end
