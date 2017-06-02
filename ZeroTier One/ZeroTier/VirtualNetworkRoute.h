//
//  VirtualNetworkRoute.h
//  ZeroTier One
//
//  Created by Grant Limberg on 8/22/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZeroTierOne.h"

@interface VirtualNetworkRoute : NSObject

@property (readonly) struct sockaddr_storage target;
@property (readonly) struct sockaddr_storage gateway;
@property (readonly) UInt16 flags;
@property (readonly) UInt16 metric;

- (id)initWithRoute:(ZT_VirtualNetworkRoute)route;

@end
