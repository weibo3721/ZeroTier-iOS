//
//  VirtualNetworkConfig.m
//  ZeroTier One
//
//  Created by Grant Limberg on 10/5/15.
//  Copyright © 2015 Zero Tier, Inc. All rights reserved.
//

#import "VirtualNetworkConfig.h"
#import "VirtualNetworkRoute.h"
#import "ZeroTier.h"

@implementation VirtualNetworkConfig

- (id)initWithNetworkConfig:(ZT_VirtualNetworkConfig)cfg {
    if((self = [super init])) {
        _nwid = cfg.nwid;
        _mac = cfg.mac;
        _name = [NSString stringWithUTF8String:(const char*)&cfg.name];
        _status = cfg.status;
        _type = cfg.type;
        _mtu = cfg.mtu;
        _dhcp = cfg.dhcp == 0 ? false : true;
        _broadcastEnabled = cfg.broadcastEnabled == 0 ? false : true;
        _bridge = cfg.bridge == 0 ? false : true;
        _portError = cfg.portError;
        _netconfRevision = cfg.netconfRevision;

        NSMutableArray<NSData*> *addresses = [NSMutableArray array];
        for(int i = 0; i < cfg.assignedAddressCount; ++i) {
            NSData *addr = [[NSData alloc] initWithBytes:(const void*)&cfg.assignedAddresses[i] length:sizeof(struct sockaddr_storage)];
            [addresses addObject:addr];
        }
        _assignedAddresses = addresses;

        NSMutableArray<VirtualNetworkRoute*> *routes = [NSMutableArray array];
        for(int i = 0; i < cfg.routeCount; ++i) {
            VirtualNetworkRoute *r = [[VirtualNetworkRoute alloc] initWithRoute:cfg.routes[i]];
            [routes addObject:r];
        }
        _routes = routes;
    }
    return self;
}

- (BOOL)requiresUpdate:(VirtualNetworkConfig*)other
{
    if(_nwid == other.nwid &&
       _mac == other.mac &&
       [_name isEqualToString:other.name] &&
       _status == other.status &&
       _type == other.type &&
       _mtu == other.mtu &&
       _dhcp == other.dhcp &&
       _broadcastEnabled == other.broadcastEnabled &&
       _bridge == other.bridge &&
       _portError == other.portError &&
       _netconfRevision == other.netconfRevision &&
       [_assignedAddresses count] == [other.assignedAddresses count] &&
       [_routes count] == [other.routes count] ) {

        return NO;
    }

    return YES;
}

@end
