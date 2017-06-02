//
//  UDPCom.m
//  ZeroTier One
//
//  Created by Grant Limberg on 10/28/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import "UDPCom.h"
#import "Reachability.h"
#import "Logger.h"
#import <ZeroTier/AddressUtils.h>
#import <ZeroTier/Node.h>
#import <ZeroTier/NetworkUtil.h>

@implementation UDPCom

extern const DDLogLevel ddLogLevel;

- (instancetype)initWithPTP:(NEPacketTunnelProvider*)ptp {
    self = [super init];
    if(self) {
        _node = nil;
        _socket = nil;
        _socket4FD = -1;
        _socket6FD = -1;
        _ptp = ptp;
    }
    return self;
}

- (void)reachabilityChanged:(NSNotification*)note {
    Reachability *curReach = (Reachability*)note.object;

    switch(curReach.currentReachabilityStatus) {
        case NotReachable:
            DDLogDebug(@"NetworkStatus: Not Reachable");
            break;
        case ReachableViaWiFi:
            DDLogDebug(@"NetworkStatus: Reachable via WiFi");
            break;
        case ReachableViaWWAN:
            DDLogDebug(@"NetworkStatus: Reachable via WWAN");
            break;
        default:
            DDLogDebug(@"NetworkStatus: Unknown");
            break;
    }
}

- (void)setupSocket {
    DDLogDebug(@"Setting up socket");
    if (_socket == nil) {
        _socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue: dispatch_get_main_queue()];

        NSError *error = nil;
        [_socket enableReusePort:YES error:&error];

        if (error) {
            DDLogError(@"Error setting reuse port: %@", error);
            error = nil;
        }

        [_socket bindToPort:9993 error:&error];

        if (error) {
            DDLogError(@"Error binding to port 9993: %@", error);
            error = nil;
        }

        [_socket beginReceiving:&error];

        if (error) {
            DDLogError(@"Error listening to port 9993: %@", error);
            error = nil;
        }

        [_socket performBlock:^{
            _socket4FD = _socket.socket4FD;
            _socket6FD = _socket.socket6FD;
        }];
    }
}

- (void)setNode:(Node*)node {
    _node = node;
}

- (void)shutdown {
    DDLogDebug(@"Shutting down UDPCom");
    [_socket pauseReceiving];
    [_socket close];
    close(_socket4FD);
    close(_socket6FD);
    _socket4FD = -1;
    _socket6FD = -1;
    DDLogDebug(@"Sockets closed");
}

- (int32_t)sendDataWithLocalAddress:(const struct sockaddr_storage*)localAddress toRemoteAddress:(const struct sockaddr_storage *)remoteAddress data:(NSData *)data ttl:(uint32_t)ttl {
    (void)localAddress;
    (void)ttl;

    struct sockaddr_storage destination = *remoteAddress;

    int32_t sent = 0;

    if (destination.ss_family == AF_INET) {
        if (_socket4FD < 0) {
            DDLogError(@"Invalid IPv4 Socket");
            [self setupSocket];
            return -2;
        }

        NSString *dest = sockaddr_getString(destination);
        DDLogDebug(@"Sending %lu byte packet to %@", data.length, dest);

        sent = (int32_t)sendto(_socket4FD, data.bytes, data.length, 0, (struct sockaddr*)&destination, sizeof(struct sockaddr_in));

        if (sent < 0) {
            DDLogError(@"Sending to %@ failed.  Try sending via NAT64", dest);
            // sending over IPv4 failed.  Try sending via NAT64
            destination = [NetworkUtil v6addressFromv4Address:remoteAddress];
        }
        else {
            return 0;
        }
    }

    if (destination.ss_family == AF_INET6) {
        if (_socket6FD < 0) {
            DDLogError(@"Invalid IPv6 socket");
            [self setupSocket];
            return -2;
        }

        NSString *dest = sockaddr_getString(destination);
        DDLogDebug(@"Sending %lu byte packet to %@", data.length, dest);

        sent = (int32_t)sendto(_socket6FD, data.bytes, data.length, 0, (struct sockaddr*)&destination, sizeof(struct sockaddr_in6));

        if (sent < 0) {
            DDLogError(@"Sending to %@ failed.", dest);
            return -1;
        }
        else {
            return 0;
        }
    }

    return -3;
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
    (void)filterContext;
    (void)sock;
    struct sockaddr_storage remoteAddr;
    [address getBytes:&remoteAddr length:sizeof(struct sockaddr_storage)];
    NSString *addrString = sockaddr_getString(remoteAddr);
    DDLogDebug(@"Received %lu bytes from %@", (unsigned long)data.length, addrString);
    [_node processWirePacket:&remoteAddr packetData:data];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error {
    (void)sock;
    if (error != nil) {
        DDLogError(@"%@", error);
    }
    DDLogDebug(@"didNotSendDataWithTag: %ld", tag);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag {
    (void)sock;
    DDLogDebug(@"didSendDataWithTag: %ld", tag);
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
    (void)sock;
    if (error != nil) {
        DDLogError(@"%@", error);
    }

    DDLogDebug(@"socket closed");
}

@end
