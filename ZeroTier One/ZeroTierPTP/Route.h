//
//  Route.h
//  ZeroTier One
//
//  Created by Grant Limberg on 9/30/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Route : NSObject <NSCopying>
{
    void *_address;
}

@property (readwrite) struct sockaddr_storage gateway;

- (id)initWithAddress:(struct sockaddr_storage)address prefix:(UInt32)prefix;

- (BOOL)isV4Route;
- (BOOL)isV6Route;

- (BOOL)belongsToRoute:(struct sockaddr_storage)address;
- (BOOL)belongsToRouteNo0Route:(struct sockaddr_storage)address;
- (BOOL)isEqual:(id)object;

@end


