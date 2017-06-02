//
//  VirtualNetworkRoute.m
//  ZeroTier One
//
//  Created by Grant Limberg on 8/22/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import "VirtualNetworkRoute.h"
#include "ZeroTierOne.h"

@implementation VirtualNetworkRoute

- (id)initWithRoute:(ZT_VirtualNetworkRoute)route {
    self = [super init];
    if(self) {
        _target = route.target;
        _gateway = route.via;
        _flags = route.flags;
        _metric = route.metric;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isMemberOfClass:[VirtualNetworkRoute class]]) {
        return NO;
    }

    VirtualNetworkRoute *rhs = (VirtualNetworkRoute*)object;
    struct sockaddr_storage rhs_target = rhs.target;
    struct sockaddr_storage rhs_gateway = rhs.gateway;
    return memcmp(&_target, &rhs_target, sizeof(struct sockaddr_storage)) == 0 &&
        memcmp(&_target, &rhs_gateway, sizeof(struct sockaddr_storage)) == 0 &&
        _flags == rhs.flags &&
        _metric == rhs.metric;
}

@end
