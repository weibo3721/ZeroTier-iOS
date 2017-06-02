//
//  NetworkConfigHandler.h
//  ZeroTier One
//
//  Created by Grant Limberg on 1/8/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZeroTierOne.h"

@class VirtualNetworkConfig;

@protocol NetworkConfigHandler

- (int32_t)onConfigChangedForNetwork:(UInt64)networkId
                           operation:(enum ZT_VirtualNetworkConfigOperation)op
                              config:(VirtualNetworkConfig*)config;

@end
