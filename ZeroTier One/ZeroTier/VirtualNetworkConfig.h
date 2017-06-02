//
//  VirtualNetworkConfig.h
//  ZeroTier One
//
//  Created by Grant Limberg on 10/5/15.
//  Copyright © 2015 Zero Tier, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZeroTierOne.h"

@class MulticastGroup;
@class VirtualNetworkRoute;

@interface VirtualNetworkConfig : NSObject

@property (readonly) UInt64 nwid;
@property (readonly) UInt64 mac;
@property (readonly) NSString *name;
@property (readonly) enum ZT_VirtualNetworkStatus status;
@property (readonly) enum ZT_VirtualNetworkType type;
@property (readonly) UInt32 mtu;
@property (readonly) BOOL dhcp;
@property (readonly) BOOL broadcastEnabled;
@property (readonly) BOOL bridge;
@property (readonly) int32_t portError;
@property (readonly) unsigned long netconfRevision;
@property (readonly) NSArray<NSData*> *assignedAddresses;
@property (readonly) NSArray<VirtualNetworkRoute*> *routes;

- (id)initWithNetworkConfig:(ZT_VirtualNetworkConfig)cfg;

- (BOOL)requiresUpdate:(VirtualNetworkConfig*)other;

@end
