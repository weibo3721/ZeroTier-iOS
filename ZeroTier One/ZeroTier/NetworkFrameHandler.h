//
//  NetworkFrameHandler.h
//  ZeroTier One
//
//  Created by Grant Limberg on 1/8/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol NetworkFrameHandler <NSObject>

- (void)onVirtualNetworkFrameFromNetwork:(UInt64)networkId
                               sourceMac:(UInt64)sourceMac
                                 destMac:(UInt64)destMac
                               etherType:(uint32_t)etherType
                                  vlanId:(uint32_t)vlanId
                                    data:(NSData*)data;

@end
