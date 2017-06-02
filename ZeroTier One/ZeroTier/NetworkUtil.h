//
//  NetworkUtil.h
//  ZeroTier One
//
//  Created by Grant Limberg on 1/29/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NetworkUtil : NSObject

+ (struct sockaddr_storage)v6addressFromv4Address:(const struct sockaddr_storage*)v4;

@end
