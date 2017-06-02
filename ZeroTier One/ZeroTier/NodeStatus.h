//
//  NodeStatus.h
//  ZeroTier One
//
//  Created by Grant Limberg on 1/8/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZeroTierOne.h"

@interface NodeStatus : NSObject

@property (readonly) UInt64 address;
@property (readonly) NSString *publicIdentity;
@property (readonly) NSString *secretIdentity;
@property (readonly) BOOL online;

- (id)initWithStatus:(ZT_NodeStatus)status;

@end
