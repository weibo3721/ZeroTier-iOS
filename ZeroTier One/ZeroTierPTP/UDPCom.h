//
//  UDPCom.h
//  ZeroTier One
//
//  Created by Grant Limberg on 10/28/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>
#import <CocoaAsyncSocket/CocoaAsyncSocket.h>
#import <ZeroTier/PacketSender.h>

@class Node;

@interface UDPCom : NSObject <PacketSender, GCDAsyncUdpSocketDelegate>
{
    Node *_node;
    GCDAsyncUdpSocket *_socket;
    int _socket4FD;
    int _socket6FD;

    NEPacketTunnelProvider *_ptp;
}

- (instancetype)initWithPTP:(NEPacketTunnelProvider*)ptp;

- (void)reachabilityChanged:(NSNotification*)note;
- (void)setupSocket;
- (void)setNode:(Node*)node;
- (void)shutdown;

- (int32_t)sendDataWithLocalAddress:(const struct sockaddr_storage*)localAddress toRemoteAddress:(const struct sockaddr_storage *)remoteAddress data:(NSData *)data ttl:(uint32_t)ttl;


@end
