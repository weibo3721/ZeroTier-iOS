//
//  TunTapAdapter.m
//  ZeroTier One
//
//  Created by Grant Limberg on 10/28/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import "TunTapAdapter.h"
#import <ZeroTier/ZeroTier.h>
#import "Route.h"
#import "Logger.h"
#import "PacketTunnelProvider.h"

#import <NetworkExtension/NetworkExtension.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

@implementation TunTapAdapter

- (instancetype)initWithPTP:(PacketTunnelProvider*)ptp {
    self = [super init];
    if (self) {
        _node = nil;
        _ptp = ptp;
        ARP_new(&_arpTable);
        _ndTable = [[NDPTable alloc] init];
        _routeMutex = [[NSObject alloc] init];
        _routeMap = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc {
    ARP_delete(_arpTable);
    _arpTable = nil;
}

- (void)setNode:(Node*)node {
    _node = node;
}

- (void)setLocalArpInfo:(UInt32)address mac:(UInt64)mac {
    ARP_addLocal(_arpTable, address, mac);
}

- (void)start {
    [_ptp.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> * _Nonnull packets, NSArray<NSNumber *> * _Nonnull protocols) {
        [self handleIncomingPackets:packets protocols:protocols];
    }];
}

- (void)handleIncomingPackets:(NSArray<NSData*>*)packets protocols:(NSArray<NSNumber*>*)protocols {
    assert(packets.count == protocols.count);

    for (int i = 0; i < packets.count; ++i) {
        NSData *packet = [packets objectAtIndex:i];
        NSNumber *protocol = [protocols objectAtIndex:i];

        switch (protocol.intValue) {
            case AF_INET:
                [self handleIPv4Packet:packet];
                break;
            case AF_INET6:
                [self handleIPv6Packet:packet];
                break;
            default:
                [self handleUnknownPacket:packet];
                break;
        }
    }

    [_ptp.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> * _Nonnull packets, NSArray<NSNumber *> * _Nonnull protocols) {
        [self handleIncomingPackets:packets protocols:protocols];
    }];
}

- (void)handleIPv4Packet:(NSData*)packet {
    struct sockaddr_storage srcAddr = getV4SourceAddressFromPacket(packet);
    struct sockaddr_storage destAddr = getV4DestAddressFromPacket(packet);
    UInt64 destNetwork = [self networkIdForDestination:destAddr];

    if (destNetwork == 0) {
        NSString *destAddressString = sockaddr_getString(destAddr);
        //DDLogError(@"Unable to find network for IPv4 destination: %@", destAddressString);
        return;
    }

    struct sockaddr_storage gateway = ZT_SOCKADDR_NULL;

    Route *route = [self routeForDestination:destAddr];

    if (route != nil) {
        if (!sockaddr_isNullAddress(route.gateway)) {
            gateway = route.gateway;
        }
    }

    VirtualNetworkConfig *config = [_node networkConfig:destNetwork];
    UInt64 myMacAddress = config.mac;

    UInt32 prefix = 0;
    for (NSData *a in config.assignedAddresses) {
        struct sockaddr_storage addr;
        [a getBytes:&addr length:sizeof(struct sockaddr_storage)];

        if (sockaddr_isV4(addr)) {
            prefix = sockaddr_getPort(addr);
        }
    }

    srcAddr = sockaddr_setPort(srcAddr, prefix);
    destAddr = sockaddr_setPort(destAddr, prefix);

    if (!sockaddr_isNullAddress(gateway)) {
        struct sockaddr_storage destNetwork = sockaddr_getNetwork(destAddr);
        struct sockaddr_storage srcNetwork = sockaddr_getNetwork(srcAddr);

        if (!sockaddrs_equal(destNetwork, srcNetwork)) {
            destAddr = gateway;
        }
    }

    void *query = malloc(128);
    UInt32 queryLen = 0;
    UInt64 queryDest = 0;

    UInt32 srcInt = sockaddrToInt(srcAddr);
    UInt32 destInt = sockaddrToInt(destAddr);
    UInt64 destMac = ARP_query(_arpTable, myMacAddress, srcInt, destInt, query, &queryLen, &queryDest);

    if (queryDest != 0 && queryLen != 0) {
        DDLogDebug(@"Unknown MAC address. Sending ARP Request");
        NSData *queryData = [NSData dataWithBytes:query length:queryLen];
        [_node processVirtualNetworkFrameForNetwork:destNetwork sourceMac:myMacAddress destMac:queryDest etherType:ARP_PACKET vlanId:0 frameData:queryData];
    }
    else {
        DDLogDebug(@"Sending %lu bytes to ZeroTier", packet.length);
        [_node processVirtualNetworkFrameForNetwork:destNetwork sourceMac:myMacAddress destMac:destMac etherType:IPV4_PACKET vlanId:0 frameData:packet];
    }
    free(query);
    query = nil;

}

- (void)handleIPv6Packet:(NSData*)packet {
    struct sockaddr_storage srcAddr = getV6SourceAddressFromPacket(packet);
    struct sockaddr_storage destAddr = getV6DestAddressFromPacket(packet);

    UInt64 destNetwork = [self networkIdForDestination:destAddr];
    NSString *destAddressString = sockaddr_getString(destAddr);

    if (destNetwork == 0) {
        //DDLogError(@"Unable to find network for IPv6 destination: %@", destAddressString);
        return;
    }

    struct sockaddr_storage gateway = ZT_SOCKADDR_NULL;
    Route *route = [self routeForDestination:destAddr];

    if (route != nil) {
        if (sockaddr_isNullAddress(route.gateway)) {
            gateway = route.gateway;
        }
    }

    VirtualNetworkConfig *config = [_node networkConfig:destNetwork];
    UInt64 myMacAddress = config.mac;

    UInt32 prefix = 0;

    for (NSData *a in config.assignedAddresses) {
        struct sockaddr_storage addr;
        [a getBytes:&addr length:sizeof(struct sockaddr_storage)];

        if (sockaddr_isV6(addr)) {
            prefix = sockaddr_getPort(addr);
        }
    }

    srcAddr = sockaddr_setPort(srcAddr, prefix);
    destAddr = sockaddr_setPort(destAddr, prefix);

    if (!sockaddr_isNullAddress(gateway)) {
        struct sockaddr_storage destNetwork = sockaddr_getNetwork(destAddr);
        struct sockaddr_storage srcNetwork = sockaddr_getNetwork(srcAddr);

        if (!sockaddrs_equal(destNetwork, srcNetwork)) {
            destAddr = gateway;
        }
    }

    UInt64 destMac = 0;
    BOOL needDiscoveryRequest = NO;

    if ([self isNeighborSolicitation:packet]) {
        if ([_ndTable hasMacForAddress:destAddr]) {
            destMac = [_ndTable macForAddress:destAddr];
        }
        else {
            destMac = ipv6ToMulticastMac(destAddr);
        }
    }
    else if ([self isNeighborAdvertisement:packet]) {
        NSString *destStr = sockaddr_getString(destAddr);
        DDLogDebug(@"Sending neighbor advertisement to %@", destStr);

        if ([_ndTable hasMacForAddress:destAddr]) {
            destMac = [_ndTable macForAddress:destAddr];
        }

        needDiscoveryRequest = YES;
    }
    else if ([_ndTable hasMacForAddress:destAddr]) {
        destMac = [_ndTable macForAddress:destAddr];
        DDLogDebug(@"Found MAC to send packet to");
    }

    if (destMac != 0) {
        DDLogDebug(@"Sending %lu bytes to ZeroTier", packet.length);
        [_node processVirtualNetworkFrameForNetwork:destNetwork sourceMac:myMacAddress destMac:destMac etherType:IPV6_PACKET vlanId:0 frameData:packet];
    }
    else {
        needDiscoveryRequest = YES;
    }

    if (needDiscoveryRequest) {
        if (destMac == 0) {
            destMac = ipv6ToMulticastMac(destAddr);
        }

        NSData *request = [NDPTable generateNeighborDiscoveryForAddress:destAddr fromAddress:srcAddr fromMac:myMacAddress];

        [_node processVirtualNetworkFrameForNetwork:destNetwork sourceMac:myMacAddress destMac:destMac etherType:IPV6_PACKET vlanId:0 frameData:request];
    }
}

- (void)handleUnknownPacket:(NSData*)packet {
    (void)packet;
    //DDLogError(@"Unknown protocol for packet");
}

- (NSString*)uint64ToHex:(UInt64)value {
    return [NSString stringWithFormat:@"%llX", value];
}

- (void)onVirtualNetworkFrameFromNetwork:(UInt64)networkId sourceMac:(UInt64)sourceMac destMac:(UInt64)destMac etherType:(uint32_t)etherType vlanId:(uint32_t)vlanId data:(NSData *)data {

    (void)vlanId;

    switch (etherType) {
        case ARP_PACKET:
            [self onARPFrameReceived:networkId sourceMac:sourceMac destMac:destMac data:data];
            break;
        case IPV4_PACKET:
            [self onIPv4FrameReceived:data];
            break;
        case IPV6_PACKET:
            [self onIPv6FrameReceived:networkId sourceMac:sourceMac destMac:destMac data:data];
            break;
        default:
            //DDLogError(@"Unknown etherType: %ud", etherType);
            break;
    }
}

- (void)onARPFrameReceived:(UInt64)networkId sourceMac:(UInt64)sourceMac destMac:(UInt64)destMac data:(NSData*)data {
    (void)destMac;
    DDLogDebug(@"Received ARP Packet");

    void *response = malloc(128);
    UInt32 responseLen = 0;
    UInt64 responseDest = 0;

    ARP_processIncomingArp(_arpTable, data.bytes, (unsigned int)data.length, response, &responseLen, &responseDest);

    if (responseLen > 0) {
        DDLogDebug(@"Sending ARP reply");
        VirtualNetworkConfig *cfg = [_node networkConfig:networkId];
        NSData *arpReply = [NSData dataWithBytes:response length:responseLen];

        [_node processVirtualNetworkFrameForNetwork:networkId sourceMac:cfg.mac destMac:sourceMac etherType:ARP_PACKET vlanId:0 frameData:arpReply];
    }
    free(response);
    response = nil;
}

- (void)onIPv4FrameReceived:(NSData*)data {
    NSMutableArray<NSData*> *packets = [NSMutableArray array];
    NSMutableArray<NSNumber*> *protocols = [NSMutableArray array];

    [packets addObject:data];
    [protocols addObject:[NSNumber numberWithInt:AF_INET]];

    DDLogDebug(@"Writing %lud bytes to tunnel adapter", (unsigned long)data.length);
    [_ptp.packetFlow writePackets:packets withProtocols:protocols];
}

- (void)onIPv6FrameReceived:(UInt64)networkId sourceMac:(UInt64)sourceMac destMac:(UInt64)destMac data:(NSData*)data {
    (void)networkId;
    (void)destMac;
    
    struct sockaddr_storage sourceAddress = getV6SourceAddressFromPacket(data);
    [_ndTable addMac:sourceMac forAddress:sourceAddress];

    if ([self isNeighborSolicitation:data]) {
        DDLogDebug(@"Got Neighbor Solicitaiton from ZT");
    }
    else if ([self isNeighborAdvertisement:data]) {
        DDLogDebug(@"Got Neighbor Advertisement from ZT");
    }

    NSMutableArray<NSData*> *packets = [NSMutableArray array];
    NSMutableArray<NSNumber*> *protocols = [NSMutableArray array];

    [packets addObject:data];
    [protocols addObject:[NSNumber numberWithInt:AF_INET6]];

    [_ptp.packetFlow writePackets:packets withProtocols:protocols];
}

- (BOOL)isNeighborSolicitation:(NSData*)packet {
    UInt8 payloadType = 0;
    [packet getBytes:&payloadType range:NSMakeRange(6, 1)];

    if (payloadType == IPV6_ICMPV6) {
        UInt8 icmpType = 0;
        [packet getBytes:&icmpType range:NSMakeRange(40, 1)];

        if (icmpType == 135) {
            return YES;
        }
    }

    return NO;
}

- (BOOL)isNeighborAdvertisement:(NSData*)packet {
    UInt8 payloadType = 0;
    [packet getBytes:&payloadType range:NSMakeRange(6, 1)];

    if (payloadType == IPV6_ICMPV6) {
        UInt8 icmpType = 0;
        [packet getBytes:&icmpType range:NSMakeRange(40, 1)];

        if (icmpType == 136) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)isNeighborDiscovery:(NSData*)packet {
    return [self isNeighborSolicitation:packet] || [self isNeighborAdvertisement:packet];
}

- (void)addRouteAndNetwork:(Route*)route nwid:(UInt64)network {
    @synchronized (_routeMutex) {
        [_routeMap setObject:[NSNumber numberWithUnsignedLongLong:network] forKey:route];
    }
}

- (void)clearRouteMap {
    @synchronized (_routeMutex) {
        [_routeMap removeAllObjects];
    }
}

- (UInt64)networkIdForDestination:(struct sockaddr_storage)dest {
    @synchronized (_routeMutex) {
        for (Route *r in _routeMap.allKeys) {
            if ([r belongsToRoute:dest]) {
                return [_routeMap objectForKey:r].unsignedLongLongValue;
            }
        }
    }
    return 0;
}

- (Route*)routeForDestination:(struct sockaddr_storage)dest {
    @synchronized (_routeMutex) {
        for (Route *r in _routeMap.allKeys) {
            if ([r belongsToRoute:dest]) {
                return r;
            }
        }
    }

    return nil;
}

@end
