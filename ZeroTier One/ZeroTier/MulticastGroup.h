//
//  MulticastGroup.h
//  ZeroTier One
//
//  Created by Grant Limberg on 1/8/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZeroTierOne.h"

@interface MulticastGroup : NSObject

@property (readonly) UInt64 mac;
@property (readonly) unsigned long adi;

- (id)initWithGroup:(ZT_MulticastGroup)group;

@end
