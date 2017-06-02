//
//  PeerPhysicalPath.h
//  ZeroTier One
//
//  Created by Grant Limberg on 1/8/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ZeroTierOne.h"

@interface PeerPhysicalPath : NSObject

- (id)initWithPath:(ZT_PeerPhysicalPath)path;

@property (readonly) NSData *address;
@property (readonly) uint64_t lastSend;
@property (readonly) uint64_t lastReceive;
@property (readonly) uint64_t trustedPathId;
@property (readonly) int32_t expired;
@property (readonly) int32_t preferred;

@end
