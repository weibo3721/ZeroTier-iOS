//
//  NodeStatus.m
//  ZeroTier One
//
//  Created by Grant Limberg on 1/8/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import "NodeStatus.h"

@implementation NodeStatus

- (id)initWithStatus:(ZT_NodeStatus)status {
    self = [super init];

    if(self) {
        _address = status.address;
        _publicIdentity = [NSString stringWithUTF8String:status.publicIdentity];
        _secretIdentity = [NSString stringWithUTF8String:status.secretIdentity];
        _online = status.online;
    }

    return self;
}
@end
