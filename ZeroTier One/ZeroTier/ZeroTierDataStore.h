//
//  ZeroTierDataStore.h
//  ZeroTier One
//
//  Created by Grant Limberg on 1/8/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZeroTierDataStore : NSObject

- (NSData*)getObjectWithName:(NSString*)name atStartIndex:(uint64_t)startIndex totalSize:(uint64_t*)totalSize;

- (int32_t)putObjectWithName:(NSString*)name buffer:(NSData*)buffer secure:(BOOL)secure;

- (BOOL)deleteObjectWithName:(NSString*)name;

@end
