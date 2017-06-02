//
//  PacketSender.h
//  ZeroTier One
//
//  Created by Grant Limberg on 1/8/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PacketSender <NSObject>

- (int32_t) sendDataWithLocalAddress:(const struct sockaddr_storage*)localAddress
                     toRemoteAddress:(const struct sockaddr_storage*)remoteAddress
                                data:(NSData*)data
                                 ttl:(uint32_t)ttl;

@end
