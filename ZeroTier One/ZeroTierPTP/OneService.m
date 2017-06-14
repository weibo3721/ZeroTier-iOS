//
//  OneService.m
//  ZeroTier One
//
//  Created by Grant Limberg on 10/28/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import "OneService.h"
#import "UDPCom.h"
#import "TunTapAdapter.h"
#import "Logger.h"
#import "Route.h"
#import "ZeroTierOne.h"
#import "PacketTunnelProvider.h"

#import <NetworkExtension/NetworkExtension.h>

NSString * _Nonnull const statusNotificationKey = @"com.zerotier.ZeroTier-One.ZeroTierPTP.nodeStatus";
NSString * _Nonnull const oneServiceQueueKey = @"com.zerotier.ZeroTierPTP.OneServiceQueue";


@implementation OneService

- (instancetype _Nullable)initWithPTP:(PacketTunnelProvider* _Nonnull)ptp udpCom:(UDPCom * _Nonnull)udpCom {
    self = [super init];

    if (self) {
        static dispatch_once_t _creationGuard = 0;
        dispatch_once(&_creationGuard, ^{
            _queue = dispatch_queue_create([oneServiceQueueKey UTF8String], DISPATCH_QUEUE_CONCURRENT);
        });

        _node = nil;

        _udpCom = udpCom;
        _ptp = ptp;
        _configs = [NSMutableDictionary dictionary];
        _dataStore = [[ZeroTierDataStore alloc] init];

        _isRunning = NO;
    }

    return self;
}

- (void)dealloc {
    [_udpCom shutdown];
    [_configs removeAllObjects];
    _dataStore = nil;
}

- (void)runService:(BOOL)allowDefault completionHandler:(nullable void (^)(void))completionHandler {
    _runServiceCompletionHandler = completionHandler;
    _allowDefault = allowDefault;

    _isRunning = YES;

    _tunTapAdapter = [[TunTapAdapter alloc] initWithPTP:_ptp];

    _node = [[Node alloc] initWithDataStore:_dataStore
                              configHandler:self
                               eventHandler:self
                               frameHandler:_tunTapAdapter
                               packetSender:_udpCom];

    if (_node != nil) {
        [_udpCom setNode:_node];
        [_tunTapAdapter setNode:_node];

        dispatch_async(_queue, ^{
            while(_isRunning) {
                UInt64 dl = [_node nextDeadline];
                UInt64 nowTime = now();

                if (dl <= nowTime) {
                    [_node processBackgroundTasks];
                }

                UInt64 delay = ((dl > nowTime) ? (dl - nowTime) : 100) * 1000;
                if (delay > 1000000) {
                    delay = 1000000;
                }
                usleep((UInt32)delay);
            }
            DDLogDebug(@"Ended runService run loop");

            [_node shutdown];
            [_udpCom shutdown];
            [_udpCom setNode:nil];
            _tunTapAdapter = nil;
            _node = nil;
        });
    }
    else {
        //DDLogError(@"Error starting node");
        [_udpCom shutdown];

        [_ptp errorStartingNode:@"Node initialization failed"];
    }
}

- (void)stopService {
    DDLogDebug(@"stopService called");
    if (_isRunning) {
        _isRunning = false;
    }
}

- (void)onIdentityCollision {
    //DDLogError(@"Identity collision. Removing public/private key pair");

    [self stopService];

    [_dataStore deleteObjectWithName:@"identity.secret"];

    [self runService:_allowDefault completionHandler:_runServiceCompletionHandler];
}

- (void)onEvent:(enum ZT_Event)event {
    switch (event) {
        case ZT_EVENT_UP:
            DDLogDebug(@"ZT UP");
            break;
        case ZT_EVENT_DOWN:
            DDLogDebug(@"ZT DOWN");
            break;
        case ZT_EVENT_ONLINE:
            DDLogDebug(@"ZT ONLINE");
            if (_runServiceCompletionHandler != nil) {
                _runServiceCompletionHandler();
                _runServiceCompletionHandler = nil;
            }
            else {
                //DDLogError(@"Got ZT_ONLINE but completion handler is nil!");
            }
            break;
        case ZT_EVENT_OFFLINE:
            DDLogDebug(@"ZT OFFLINE");
            break;
        case ZT_EVENT_FATAL_ERROR_IDENTITY_COLLISION:
            [self onIdentityCollision];
            return;
        default:
            return;
    }

    NSDictionary *info = @{ @"status": [NSNumber numberWithUnsignedInt:event] };
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:statusNotificationKey object:self userInfo:info];
}

- (void)onTrace:(NSString * _Nonnull )message {
    DDLogDebug(@"%@", message);
}

- (int32_t)onConfigChangedForNetwork:(UInt64)networkId operation:(enum ZT_VirtualNetworkConfigOperation)op config:(VirtualNetworkConfig * _Nonnull)config {

    DDLogDebug(@"Network Config Changed");
    
    switch (op) {
        case ZT_VIRTUAL_NETWORK_CONFIG_OPERATION_UP:
            DDLogDebug(@"ZT_VIRTUAL_NETWORK_CONFIG_OPERATION_UP");
            break;
        case ZT_VIRTUAL_NETWORK_CONFIG_OPERATION_DOWN:
            DDLogDebug(@"ZT_VIRTUAL_NETWORK_CONFIG_OPERATION_DOWN");
            break;
        case ZT_VIRTUAL_NETWORK_CONFIG_OPERATION_DESTROY:
            DDLogDebug(@"ZT_VIRTUAL_NETWORK_CONFIG_OPERATION_DESTROY");
            break;
        case ZT_VIRTUAL_NETWORK_CONFIG_OPERATION_CONFIG_UPDATE:
            DDLogDebug(@"ZT_VIRTUAL_NETWORK_CONFIG_OPERATION_CONFIG_UPDATE");
            [self updateNetworkConfig:networkId config:config];
            break;
        default:
            break;
    }
    return 0;
}

- (void)updateNetworkConfig:(UInt64)nwid config:(VirtualNetworkConfig* _Nonnull)config {
    NSNumber *networkId = [NSNumber numberWithUnsignedLongLong:nwid];
    VirtualNetworkConfig *oldConfig = [_configs objectForKey:networkId];
    [_configs setObject:config forKey:networkId];

    BOOL needsUpdate = YES;

    if (oldConfig != nil) {
        needsUpdate = [oldConfig requiresUpdate:config];
    }

    if (needsUpdate) {
        [_tunTapAdapter clearRouteMap];

        NEPacketTunnelNetworkSettings *settings = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress:@"162.243.77.111"];
        settings.MTU = [NSNumber numberWithUnsignedInt:config.mtu];

        NSMutableArray<NSString*> *v4addresses = [NSMutableArray array];
        NSMutableArray<NSString*> *v4subnetMasks = [NSMutableArray array];
        NSMutableArray<NEIPv4Route*> *v4routes = [NSMutableArray array];
        NSMutableArray<NEIPv4Route*> *v4excludes = [NSMutableArray array];

        NSMutableArray<NSString*> *v6addresses = [NSMutableArray array];
        NSMutableArray<NSNumber*> *v6prefixLengths = [NSMutableArray array];
        NSMutableArray<NEIPv6Route*> *v6routes = [NSMutableArray array];
        NSMutableArray<NEIPv6Route*> *v6excludes = [NSMutableArray array];

        NSArray<NetInfo*> *excludes = getLocalNetworks();

        for (NetInfo *info in excludes) {
            DDLogDebug(@"Excluding: %@", info);
            if (info.family == AF_INET) {
                NEIPv4Route *e = [[NEIPv4Route alloc] initWithDestinationAddress:info.network subnetMask:info.netmask];
                [v4excludes addObject:e];
            }
            else if (info.family == AF_INET6) {
                NEIPv6Route *e = [[NEIPv6Route alloc] initWithDestinationAddress:info.network networkPrefixLength:info.prefix];
                [v6excludes addObject:e];
            }
        }

        for (NSData *addr in config.assignedAddresses) {
            struct sockaddr_storage address;
            [addr getBytes:&address length:addr.length];
            NSString *addressString = sockaddr_getString(address);

            if (sockaddr_isV4(address)) {
                NSString *netmaskString = sockaddr_getNetmaskString(address);
                [v4addresses addObject:addressString];
                [v4subnetMasks addObject:netmaskString];

                UInt32 addrAsInt = sockaddrToInt(address);
                UInt32 prefix = sockaddr_getPort(address);
                struct sockaddr_storage network = sockaddr_getNetwork(address);
                NSString *networkString = sockaddr_getNetworkString(network);
                Route *route = [[Route alloc] initWithAddress:address
                                                       prefix:prefix];
                NEIPv4Route *v4route = [[NEIPv4Route alloc] initWithDestinationAddress:networkString
                                                                            subnetMask:netmaskString];
                [v4routes addObject:v4route];
                [_tunTapAdapter setLocalArpInfo:addrAsInt mac:config.mac];
                [_tunTapAdapter addRouteAndNetwork:route nwid:nwid];
                UInt64 multicastGroup = sockaddr_getMulticastGroup(address);
                UInt32 multicastAdi = sockaddr_getMulticastAdi(address);
                [_node multicastSubscribe:nwid
                           multicastGroup:multicastGroup
                             multicastAdi:multicastAdi];
            }
            else if (sockaddr_isV6(address)) {
                [v6addresses addObject:addressString];
//                struct sockaddr_in6 ipv6;
//                memcpy(&ipv6, &address, sizeof(struct sockaddr_in6));
                UInt32 prefixLength = sockaddr_getPort(address);
                [v6prefixLengths addObject:[NSNumber numberWithUnsignedInt:prefixLength]];

                struct sockaddr_storage network = sockaddr_getNetwork(address);
                Route *route = [[Route alloc] initWithAddress:network
                                                       prefix:prefixLength];
                [_tunTapAdapter addRouteAndNetwork:route
                                              nwid:nwid];

                UInt64 mcast = sockaddr_getMulticastGroup(address);
                UInt32 adi = sockaddr_getMulticastAdi(address);

                [_node multicastSubscribe:nwid
                           multicastGroup:mcast
                             multicastAdi:adi];

                NSString *networkString = sockaddr_getNetworkString(address);
                NEIPv6Route *v6route = [[NEIPv6Route alloc] initWithDestinationAddress:networkString
                                                                   networkPrefixLength:[NSNumber numberWithUnsignedInt:prefixLength]];
                [v6routes addObject:v6route];
            }
        }

        if ([config.routes count] > 0) {
            NEIPv4Route *defaultRouteV4 = [NEIPv4Route defaultRoute];
            NEIPv6Route *defaultRouteV6 = [NEIPv6Route defaultRoute];

            for (VirtualNetworkRoute *r in config.routes) {
                struct sockaddr_storage target = r.target;
                struct sockaddr_storage gateway = r.gateway;

                NSString *netmaskString = sockaddr_getNetmaskString(target);
                unsigned int prefix = sockaddr_getPort(target);
                struct sockaddr_storage network = sockaddr_getNetwork(target);
                NSString *networkString = sockaddr_getNetworkString(target);

                DDLogDebug(@"Network: %@/%ud", networkString, prefix);

                Route *route = [[Route alloc] initWithAddress:network
                                                       prefix:prefix];

                if (sockaddr_isV4(target)) {
                    NEIPv4Route *v4route = nil;

                    if (_allowDefault && [networkString isEqualToString:defaultRouteV4.destinationAddress]) {
                        v4route = defaultRouteV4;
                    }
                    else {
                        v4route = [[NEIPv4Route alloc] initWithDestinationAddress:networkString
                                                                       subnetMask:netmaskString];
                    }

                    if (gateway.ss_family != 0) {
                        NSString *gatewayString = sockaddr_getString(gateway);
                        if([gatewayString length] > 0) {
                            v4route.gatewayAddress = gatewayString;
                            route.gateway = gateway;
                        }
                        else {
                            continue;
                        }
                    }
                    else {
                        continue;
                    }

                    DDLogInfo(@"Added Route: %@/%@ Gateway: %@", v4route.destinationAddress, v4route.destinationSubnetMask, v4route.gatewayAddress);

                    [v4routes addObject:v4route];
                }
                else if (sockaddr_isV6(target)) {
                    NEIPv6Route *v6route = nil;
                    if (_allowDefault && ([networkString isEqualToString:@"::"] || [networkString isEqualToString:@"0000:0000:0000:0000:0000:0000:0000:0000"])) {
                        v6route = defaultRouteV6;
                    }
                    else {
                        v6route = [[NEIPv6Route alloc] initWithDestinationAddress:networkString
                                                              networkPrefixLength:[NSNumber numberWithUnsignedInt:prefix]];
                    }

                    if (gateway.ss_family != 0) {
                        NSString *gatewayString = sockaddr_getString(gateway);
                        if ([gatewayString length] > 0) {
                            v6route.gatewayAddress = gatewayString;
                            route.gateway = gateway;
                        }
                        else {
                            continue;
                        }
                    }
                    else {
                        continue;
                    }

                    DDLogInfo(@"Added Route: %@/%@ Gateway: %@", v6route.destinationAddress, v6route.destinationNetworkPrefixLength, v6route.gatewayAddress);

                    [v6routes addObject:v6route];
                }
                [_tunTapAdapter addRouteAndNetwork:route nwid:nwid];
            }
        }

        settings.IPv4Settings = [[NEIPv4Settings alloc] initWithAddresses:v4addresses
                                                              subnetMasks:v4subnetMasks];
        settings.IPv4Settings.includedRoutes = v4routes;
          
        

        NEIPv4Route * test = [[NEIPv4Route alloc] initWithDestinationAddress:@"14.136.104.10" subnetMask:@"255.255.255.255"];
        
        [v4excludes addObject:test];
        
        DDLogError(@"v4excludes, 14.136.104.10");
        
        //if ([v4excludes count] > 0) {
            settings.IPv4Settings.excludedRoutes = v4excludes;
        //}

        settings.IPv6Settings = [[NEIPv6Settings alloc] initWithAddresses:v6addresses
                                                     networkPrefixLengths:v6prefixLengths];
        settings.IPv6Settings.includedRoutes = v6routes;

        if ([v6excludes count] > 0) {
            settings.IPv6Settings.excludedRoutes = v6excludes;
        }

        settings.DNSSettings = [[NEDNSSettings alloc] initWithServers:@[@"8.8.8.8", @"8.8.4.4", @"2001:4860:4860::8888", @"2001:4860:4860::8844"]];

        __weak typeof(self) weakSelf = self;
        [_ptp setTunnelNetworkSettings:settings completionHandler:^(NSError * _Nullable error) {
            if (error) {
                //DDLogError(@"%@", error);
                return;
            }

            DDLogDebug(@"Whoah. We configured the adapter!");

            [weakSelf.tunTapAdapter start];
        }];
    }

}

- (void)joinNetwork:(UInt64)networkId {
    [_node joinNetwork:networkId];
}

- (void)leaveNetwork:(UInt64)networkId {
    [_node leaveNetwork:networkId];
}

- (UInt64)getDeviceID {
    if (_node != nil) {
        return [_node address];
    }
    return 0;
}


@end
