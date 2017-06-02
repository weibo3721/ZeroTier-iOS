//
//  MulticastGroup.m
//  ZeroTier One
//
//  Created by Grant Limberg on 1/8/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import "MulticastGroup.h"

@implementation MulticastGroup

- (id)initWithGroup:(ZT_MulticastGroup)group {
    self = [super init];

    if(self) {
        _mac = group.mac;
        _adi = group.adi;
    }

    return self;
}

@end
