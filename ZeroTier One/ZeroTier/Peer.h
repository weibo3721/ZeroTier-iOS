//
//  Peer.h
//  ZeroTier One
//
//  Created by Grant Limberg on 10/5/15.
//  Copyright © 2015 Zero Tier, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZeroTierOne.h"

@class PeerPhysicalPath;

@interface Peer : NSObject

@property (readonly) uint64_t address;
@property (readonly) int versionMajor;
@property (readonly) int versionMinor;
@property (readonly) int versionRev;
@property (readonly) unsigned int latency;
@property (readonly) enum ZT_PeerRole role;
@property (readonly) NSArray<PeerPhysicalPath*> *paths;

- (id)initWithPeer:(ZT_Peer)peer;

@end
