//
//  EventHandler.h
//  ZeroTier One
//
//  Created by Grant Limberg on 1/8/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZeroTierOne.h"

@protocol EventHandler <NSObject>

- (void)onEvent:(enum ZT_Event)event;
- (void)onTrace:(NSString*)message;

@end
