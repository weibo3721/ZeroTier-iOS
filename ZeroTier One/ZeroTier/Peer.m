//
//  Peer.m
//  ZeroTier One
//
//  Created by Grant Limberg on 10/5/15.
//  Copyright © 2015 Zero Tier, Inc. All rights reserved.
//

#import "Peer.h"
#import "PeerPhysicalPath.h"

@implementation Peer

- (id)initWithPeer:(ZT_Peer)peer {
    if((self = [super init])) {
        _address = peer.address;
        _versionMajor = peer.versionMajor;
        _versionMinor = peer.versionMinor;
        _versionRev = peer.versionRev;
        _latency = peer.latency;
        _role = peer.role;

        NSMutableArray<PeerPhysicalPath*> *paths = [NSMutableArray array];

        for(unsigned int i = 0; i < peer.pathCount; ++i) {
            PeerPhysicalPath *p = [[PeerPhysicalPath alloc] initWithPath:peer.paths[i]];
            [paths addObject:p];
        }

        _paths = paths;
    }
    return self;
}

@end
