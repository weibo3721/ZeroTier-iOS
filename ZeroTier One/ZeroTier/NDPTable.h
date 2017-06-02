//
//  NDPTable.h
//  ZeroTier One
//
//  Created by Grant Limberg on 10/6/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>



@interface NDPTable : NSObject

- (BOOL)hasMacForAddress:(struct sockaddr_storage)addr;
- (UInt64)macForAddress:(struct sockaddr_storage)addr;
- (void)addMac:(UInt64)mac forAddress:(struct sockaddr_storage)addr;

+ (NSData*)generateNeighborDiscoveryForAddress:(struct sockaddr_storage)to fromAddress:(struct sockaddr_storage)from fromMac:(UInt64)mac;

+ (NSData*)generateNeighborAdvertiesementForAddress:(struct sockaddr_storage)to fromAddress:(struct sockaddr_storage)from fromMac:(UInt64)mac;

@end
