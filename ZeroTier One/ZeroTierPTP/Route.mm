//
//  Route.m
//  ZeroTier One
//
//  Created by Grant Limberg on 9/30/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import "Route.h"
#import <sys/socket.h>

#include "InetAddress.hpp"

#define addr reinterpret_cast<ZeroTier::InetAddress*>(_address)

@interface Route ()

- (void)setAddress:(void*)address;

@end

@implementation Route

- (id)initWithAddress:(struct sockaddr_storage)address prefix:(UInt32)prefix {
    self = [super init];

    if(self) {
        _gateway = ZT_SOCKADDR_NULL;
        _address = (void*)new ZeroTier::InetAddress(address);
        addr->setPort(prefix);
    }

    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    Route *newCopy = [[[self class] allocWithZone:zone] init];
    newCopy.gateway = _gateway;
    [newCopy setAddress:new ZeroTier::InetAddress((ZeroTier::InetAddress*)_address)];

    return newCopy;
}

- (void)setAddress:(void *)address {
    _address = address;
}

- (BOOL)isV4Route {
    return addr->isV4();
}

- (BOOL)isV6Route {
    return addr->isV6();
}

- (BOOL)belongsToRoute:(struct sockaddr_storage)address {
    return addr->containsAddress(address);
}

- (BOOL)belongsToRouteNo0Route:(struct sockaddr_storage)address {
    return addr->containsAddress(address);
}

- (BOOL)isEqual:(id)object {
    if( object == self) {
        return YES;
    }

    if ([object isKindOfClass:[Route class]]) {
        Route *o = (Route*)object;

        return (*addr == *reinterpret_cast<ZeroTier::InetAddress*>(o->_address)) &&
               (ZeroTier::InetAddress(_gateway) == ZeroTier::InetAddress(o->_gateway));

    }
    return NO;
}

- (NSString*)description {
    NSString *network = [NSString stringWithUTF8String:addr->toString().c_str()];

    NSString *gate = nil;

    if ( memcmp(&_gateway, &ZT_SOCKADDR_NULL, sizeof(sockaddr_storage)) == 0 ) {
        gate = @"none";
    }
    else {
        ZeroTier::InetAddress gw(_gateway);
        gate = [NSString stringWithUTF8String:gw.toString().c_str()];
    }

    return [NSString stringWithFormat:@"Network: %@ Gateway: %@", network, gate, nil];
}

- (NSUInteger)hash {
    unsigned long addrHash = addr->hashCode();
    unsigned long gwHash = ZeroTier::InetAddress(_gateway).hashCode();
    unsigned long h = addrHash ^ gwHash;
    return h;
}

@end
