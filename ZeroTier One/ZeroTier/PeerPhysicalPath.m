//
//  PeerPhysicalPath.m
//  ZeroTier One
//
//  Created by Grant Limberg on 1/8/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import "PeerPhysicalPath.h"

@implementation PeerPhysicalPath

- (id)initWithPath:(ZT_PeerPhysicalPath)path {
    self = [super init];

    if (self) {
        _lastSend = path.lastSend;
        _lastReceive = path.lastReceive;
        _trustedPathId = path.trustedPathId;
        _preferred = path.preferred;
        _expired = path.expired;
        _address = [NSData dataWithBytes:&path.address length:sizeof(struct sockaddr_storage)];
        
    }

    return self;
}
@end
