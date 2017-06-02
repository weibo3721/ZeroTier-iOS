//
//  ZeroTierDataStore.m
//  ZeroTier One
//
//  Created by Grant Limberg on 1/8/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import "ZeroTierDataStore.h"
#import "FilesystemUtils.h"

@implementation ZeroTierDataStore

- (NSData*)getObjectWithName:(NSString*)name atStartIndex:(uint64_t)startIndex totalSize:(uint64_t*)totalSize {

    NSURL *file = [[FilesystemUtils applicationDataDirectory] URLByAppendingPathComponent:name];

    NSData *data = [NSData dataWithContentsOfURL:file];

    if(data) {
        *totalSize = (uint64_t)[data length];
        return data;
    }

    *totalSize = 0;
    return nil;
}

- (int32_t)putObjectWithName:(NSString*)name buffer:(NSData*)buffer secure:(BOOL)secure {
    NSURL *file = [[FilesystemUtils applicationDataDirectory] URLByAppendingPathComponent:name];

    if([name containsString:@"/"]) {
        NSArray<NSString*> *items = [name componentsSeparatedByString:@"/"];

        NSString *subdirName = [items objectAtIndex:0];

        NSURL *subdir = [[FilesystemUtils applicationDataDirectory] URLByAppendingPathComponent:subdirName];

        NSFileManager *sharedFM = [NSFileManager defaultManager];

        NSError *error = nil;

        [sharedFM createDirectoryAtURL:subdir withIntermediateDirectories:TRUE attributes:nil error:&error];
        if(error) {
            NSLog(@"Error creating subdirectory");
        }
    }

    if([buffer writeToURL:file atomically:YES]) {
        return 0;
    }

    return 1;
}

- (BOOL)deleteObjectWithName:(NSString*)name {
    NSURL *file = [[FilesystemUtils applicationDataDirectory] URLByAppendingPathComponent:name];

    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtURL:file error:&error];

    if(error) {
        return false;
    }

    return true;
}

@end
